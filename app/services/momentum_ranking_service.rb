# Cross-sectional momentum: peringkat universe by return trailing "6-1"
# (6 bulan, skip 1 bulan terakhir untuk hindari reversal jangka pendek), ambil top-N.
# Overlay: gate regime IHSG (cash saat risk-off) + filter likuiditas.
#
# Pergeseran filosofi dari confluence/squeeze/swing (yang men-timing entry pakai
# indikator & terbukti tak ada edge): di sini kita me-RANKING kekuatan relatif dan
# membiarkan pemenang berlanjut. Anomali momentum = paling terdokumentasi & robust.
class MomentumRankingService
  LOOKBACK      = 126   # ~6 bulan bursa
  SKIP          = 21    # ~1 bulan (lewati agar tak kena reversal jangka pendek)
  TOP_N         = 10
  MIN_LIQUIDITY = 1_000_000_000   # Rp 1 miliar avg turnover harian (pindah dari IdxScannerService yang dihapus)
  # Filter anti-gorengan (tervalidasi backtest: DD turun ~2/3, Sharpe naik, alpha membaik):
  MAX_MOMENTUM  = 1.0   # buang pump parabolik >100%/6bln (return rapuh, rawan crash)
  MIN_PRICE     = 100   # buang saham receh < Rp 100 (rawan manipulasi)
  # Feasibility posisi: satu posisi (portofolio/top_n) tak boleh > 5% turnover harian —
  # lebih dari itu, entry/exit ritel akan menggerakkan harga (slippage tak terkendali).
  PORTFOLIO_IDR      = ENV.fetch("PORTFOLIO_IDR", 100_000_000).to_f   # nilai portofolio acuan
  MAX_TURNOVER_SHARE = 0.05
  FLOW_WINDOW        = 20    # hari bursa untuk rasio aliran dana asing

  # Filter kualitas (tervalidasi backtest sebelum jadi default):
  #   max_momentum:  buang pump parabolik (>100%/6bln = pump, bukan momentum)
  #   min_price:     buang saham receh (< Rp 100) yang rawan manipulasi
  #   max_extension: anti-chase — tunda entry kalau close terlalu jauh di atas MA20
  #                  (mis. 0.15 = >15% di atas MA20 = overextended, rawan pullback).
  #                  Default OFF sampai backtest membuktikan membaik (plan #5).
  # ignore_regime: hitung ranking WALAU risk-off — HANYA untuk melihat (watchlist),
  # BUKAN sinyal beli. Regime tetap gate saat aksi nyata (snapshot/paper/live).
  # min_flow_ratio: overlay SMART MONEY (hipotesis, default OFF sampai terbukti).
  #   Buang kandidat yang net beli asing 20 hari / turnover 20 hari-nya di bawah
  #   ambang ini. 0.0 = "asing net beli". nil = filter mati.
  #   Saham yang datanya BELUM ADA (rasio nil) TIDAK dibuang — lihat #passes_flow?.
  def initialize(as_of: nil, symbols: nil, lookback: LOOKBACK, skip: SKIP, top_n: TOP_N,
                 max_momentum: MAX_MOMENTUM, min_price: MIN_PRICE, max_extension: nil,
                 portfolio_idr: PORTFOLIO_IDR, ignore_regime: false, residual: false,
                 min_flow_ratio: nil, max_flow_ratio: nil, flow_window: FLOW_WINDOW)
    @as_of         = as_of
    @symbols       = symbols
    @lookback      = lookback
    @skip          = skip
    @top_n         = top_n
    @max_momentum  = max_momentum
    @min_price     = min_price
    @max_extension = max_extension
    @portfolio_idr = portfolio_idr.to_f
    @ignore_regime = ignore_regime
    @residual      = residual
    @min_flow_ratio = min_flow_ratio
    @max_flow_ratio = max_flow_ratio   # plasebo: pertahankan yang asing NET JUAL
    @flow_window    = flow_window
  end

  def universe
    @symbols || IdxUniverseService.all
  end

  # Returns [{symbol:, momentum:, last_close:}, ...] top-N by momentum, atau []
  # kalau regime risk-off (portofolio ke cash).
  def call
    return [] if !@ignore_regime && IdxMarketState.long_blocked?

    eligible = universe.filter_map { |sym| score(sym) }
                       .select { |r| passes_flow?(r[:symbol]) }
                       .sort_by { |r| -r[:momentum] }

    with_scores(eligible).first(@top_n)
  end

  # Jumlah kandidat yang LOLOS seluruh filter kelayakan (likuiditas, harga minimum,
  # anti-pump, feasibility posisi). Penyebut skor persentil — dipakai laporan harian
  # supaya "skor 96" bisa dibaca sebagai "96 dari sekian saham", bukan angka gaib.
  def eligible_count = @eligible_count.to_i

  # Skor 0-100 = PERSENTIL momentum di antara kandidat layak. Bukan model, bukan
  # prediksi, bukan probabilitas: ia hanya menyatakan ulang peringkat dalam skala
  # yang bisa dibaca ("96" = mengungguli 96% kandidat layak hari itu).
  #
  # Sengaja TIDAK memasukkan aliran dana asing sebagai bobot. Overlay itu gagal uji
  # permutasi (p ~ 0,32, lihat docs/backtest-results.md); menjadikannya komponen skor
  # akan menyelundupkan sinyal tak tervalidasi ke dalam angka yang terlihat resmi.
  # Ia ditampilkan sebagai INFORMASI di laporan, bukan sebagai bagian skor.
  def with_scores(eligible)
    @eligible_count = eligible.size
    n = eligible.size
    return eligible if n.zero?

    eligible.each_with_index.map do |row, i|
      # i=0 (terbaik) -> 100 ; i=n-1 (terburuk) -> 0 saat n>1
      pct = n == 1 ? 100 : ((n - 1 - i).to_f / (n - 1) * 100).round
      row.merge(score: pct, rank_of: n)
    end
  end

  # Overlay smart money. Mati (nil) = semua lolos, persis perilaku sebelumnya.
  #
  # Rasio nil (data asing belum ada untuk simbol itu) LOLOS, tidak dibuang. Kalau
  # nil dianggap gagal, filter berubah diam-diam menjadi "hanya saham yang kebetulan
  # sudah di-ingest" — dan backtest-nya akan mengukur cakupan data, bukan hipotesis.
  def passes_flow?(symbol)
    return true if @min_flow_ratio.nil? && @max_flow_ratio.nil?
    r = flow_ratios[symbol]
    return true if r.nil?
    return false if @min_flow_ratio && r < @min_flow_ratio
    return false if @max_flow_ratio && r > @max_flow_ratio
    true
  end

  def flow_ratios
    @flow_ratios ||= IdxForeignFlowService.flow_ratios(universe, as_of: @as_of, window: @flow_window)
  end

  private

  def score(symbol)
    scope = Candle.for_asset("stock").for_symbol(symbol).for_timeframe("1d")
    scope = scope.where("opened_at <= ?", @as_of) if @as_of
    candles = scope.ordered.last(@lookback + @skip + 5)
    return nil if candles.length < @lookback + @skip + 1

    closes  = candles.map { |c| c.close.to_f }
    last    = closes.last
    return nil if last.zero?
    return nil if @min_price && last < @min_price   # buang saham receh

    # Likuiditas: avg turnover 20 hari (avg volume × harga).
    avg_vol  = candles.last(20).sum { |c| c.volume.to_f } / 20.0
    turnover = avg_vol * last
    return nil if turnover < MIN_LIQUIDITY

    # Feasibility: ukuran posisi harus muat di turnover harian (eksekusi realistis).
    if @portfolio_idr.positive?
      position = @portfolio_idr / @top_n
      return nil if position > turnover * MAX_TURNOVER_SHARE
    end

    recent = closes[-(@skip + 1)]                 # harga ~1 bulan lalu
    past   = closes[-(@skip + @lookback + 1)]      # harga ~7 bulan lalu
    return nil if past.nil? || past.zero?

    mom = if @residual
      residual_momentum(candles) or return nil
    else
      recent / past - 1.0
    end
    return nil if @max_momentum && mom > @max_momentum   # buang pump parabolik

    # Anti-chase: overextended di atas MA20 → rawan pullback tajam, tunda entry.
    if @max_extension
      ma20 = closes.last(20).sum / 20.0
      return nil if ma20.positive? && last > ma20 * (1 + @max_extension)
    end

    { symbol: symbol, momentum: mom.round(4), last_close: last }
  end

  # Momentum RESIDUAL (beta-adjusted): bagian return yang TIDAK dijelaskan gerakan IHSG.
  # OLS satu faktor DENGAN intercept atas return harian (log) di jendela momentum;
  # skornya = intercept × jumlah hari, dikembalikan sebagai return biasa supaya filter
  # MAX_MOMENTUM & tampilan persen tetap bermakna. Ini Jensen's alpha atas jendela itu.
  #
  # Kenapa intercept, bukan Σresidual: dengan intercept Σresidual in-sample = 0, jadi
  # intercept-lah yang memuat return tak terjelaskan. Varian tanpa intercept sempat
  # dicoba dan DIBUANG — beta-nya menyerap sebagian drift saham (bias sistematis yang
  # justru mengecilkan sinyal yang dicari).
  #
  # Ini varian SATU faktor — bukan residual momentum 3-faktor Blitz; IDX tak punya
  # faktor SMB/HML gratis. Hipotesis yang diuji: ranking tanpa tilt beta (saham yang
  # naik cuma karena ikut indeks tersaring) lebih baik dari return mentah.
  def residual_momentum(candles)
    window = candles[-(@skip + @lookback + 1)..-(@skip + 1)]
    return nil if window.nil? || window.length < 30

    mkt   = ihsg_by_date
    pairs = window.each_cons(2).filter_map do |a, b|
      ia = mkt[a.opened_at.to_date]
      ib = mkt[b.opened_at.to_date]
      pa = a.close.to_f
      pb = b.close.to_f
      # Harus POSITIF, bukan sekadar bukan-nol — dan ib WAJIB ikut diperiksa:
      #   nol     → log(0) = -Infinity → m_bar -Infinity → denom NaN, dan
      #             `denom.zero?` di bawah TIDAK menangkap NaN;
      #   negatif → Math.log melempar Math::DomainError, dan di SELURUH jalur ini
      #             tidak ada rescue sama sekali (baik di service ini maupun di
      #             MomentumSnapshotJob), jadi satu simbol rusak menjatuhkan
      #             SELURUH ranking.
      # Syarat <= 0 ini mencakup cek .zero? sebelumnya, jadi guardnya justru
      # lebih pendek sekaligus lebih ketat.
      next if ia.nil? || ib.nil? || ia <= 0 || ib <= 0 || pa <= 0 || pb <= 0
      [ Math.log(pb / pa), Math.log(ib / ia) ]
    end
    return nil if pairs.length < 30   # data indeks bolong → jangan reka

    n     = pairs.size
    s_bar = pairs.sum { |s, _| s } / n
    m_bar = pairs.sum { |_, m| m } / n
    denom = pairs.sum { |_, m| (m - m_bar)**2 }
    return nil if denom.zero?   # indeks tak bergerak → beta tak terdefinisi

    beta  = pairs.sum { |s, m| (m - m_bar) * (s - s_bar) } / denom
    alpha = s_bar - beta * m_bar          # return harian tak terjelaskan indeks
    mom   = Math.exp(alpha * n) - 1.0
    # Sabuk + bretel: satu NaN/Infinity yang lolos ke hasil membuat MAX_MOMENTUM
    # tak menyaring (`NaN > cap` false) dan meledakkan sort_by di #call — SATU
    # simbol rusak menjatuhkan SELURUH ranking. Lebih baik simbolnya dibuang.
    return nil unless mom.finite?

    mom
  end

  # Close IHSG per tanggal (as-of aware) — pembanding untuk regresi residual.
  # Close tak-positif (data Yahoo rusak) DIBUANG di sumber, sama seperti
  # IdxMarketState.closes_as_of: lebih baik satu tanggal bolong (pasangan
  # return-nya di-skip) daripada nol/negatif masuk ke log() dan meracuni regresi
  # — nol memberi -Infinity, negatif melempar Math::DomainError.
  def ihsg_by_date
    @ihsg_by_date ||= begin
      scope = Candle.where(asset_type: "index", symbol: IdxMarketState::SYMBOL, timeframe: "1d")
      scope = scope.where("opened_at <= ?", @as_of) if @as_of
      scope.order(:opened_at).pluck(:opened_at, :close)
           .each_with_object({}) do |(t, c), h|
             close = c.to_f
             h[t.to_date] = close if close.positive?
           end
    end
  end
end

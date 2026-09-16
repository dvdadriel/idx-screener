# Backtester PORTOFOLIO untuk strategi momentum — satu-satunya backtester yang
# tersisa setelah strategi per-trade (confluence/squeeze/swing) dihapus.
# Simulasi rebalance bulanan: tiap ~21 hari bursa, mark-to-market holding, ranking
# ulang as-of, ganti ke top-N (equal weight), potong biaya turnover. Equity ber-compound
# → return & max drawdown akun NYATA. Regime as-of ditangani MomentumRankingService.
#
# Metodologi jujur: entry/exit di CLOSE tanggal rebalance (rebalance bulanan tak sensitif
# 1 hari); tanpa lookahead (ranking pakai data <= tanggal). Biaya = cost_pct per leg per
# posisi berubah. Survivorship: universe = saham listed sekarang (bias optimis, dicatat).
class MomentumBacktestService
  REBALANCE_DAYS = 21   # ~bulanan (hari bursa)
  CALENDAR_SYM   = IdxMarketState::SYMBOL   # ^JKSE = kalender pasar

  def initialize(symbols:, days: 365, offset_days: 0, top_n: 10,
                 lookback: MomentumRankingService::LOOKBACK, skip: MomentumRankingService::SKIP,
                 cost_pct: 0.4, rebalance_days: REBALANCE_DAYS,
                 max_momentum: MomentumRankingService::MAX_MOMENTUM, min_price: MomentumRankingService::MIN_PRICE,
                 max_extension: nil, regime_confirm_days: 0, buffer_n: nil, residual: false,
                 min_flow_ratio: nil, max_flow_ratio: nil)
    @symbols   = Array(symbols)
    @days      = days.to_i
    @offset    = offset_days.to_i
    @top_n     = top_n
    @lookback  = lookback
    @skip      = skip
    @cost      = cost_pct.to_f
    @rebalance = rebalance_days
    @max_momentum = max_momentum
    @max_extension = max_extension
    @min_price    = min_price
    @regime_confirm_days = regime_confirm_days.to_i
    # Buffer zone: beli hanya top_n, tapi TAHAN posisi lama selama masih di top buffer_n.
    # Tujuannya memangkas turnover (fee 0.4%/leg) tanpa mengubah sinyalnya. nil/<=top_n = mati.
    @buffer_n = buffer_n.to_i
    @buffer_n = 0 if @buffer_n <= @top_n
    @residual = residual   # ranking pakai momentum residual (beta-adjusted) vs return mentah
    @min_flow_ratio = min_flow_ratio   # overlay smart money (nil = mati)
    @max_flow_ratio = max_flow_ratio   # plasebo terbalik
  end

  def call
    Thread.current[:regime_confirm_days] = @regime_confirm_days
    ensure_data
    prices = load_prices                       # symbol => [Candle,...] asc
    check_coverage!(prices)
    dates  = rebalance_dates
    return empty_report if dates.length < 2

    equity = 100.0
    peak = 100.0
    maxdd = 0.0
    holdings = []
    prev_px  = {}
    period_rets = []
    cash_periods = 0

    dates.each do |d|
      # 1) mark-to-market holding sejak rebalance sebelumnya (equal weight)
      unless holdings.empty?
        rets = holdings.map { |s| px = price_at(prices[s], d); pv = prev_px[s]; (px && pv && pv > 0) ? px / pv - 1.0 : 0.0 }
        pr = rets.sum / rets.size
        equity *= (1 + pr)
        period_rets << pr
      end
      cash_periods += 1 if holdings.empty?

      # 2) ranking ulang as-of tanggal ini
      Thread.current[:backtest_as_of] = d
      target = rank_at(d, holdings)

      # 3) biaya turnover: tiap posisi masuk/keluar kena cost_pct pada bobot 1/N
      changed = (holdings - target).size + (target - holdings).size
      denom   = [ @top_n, 1 ].max
      equity *= (1 - (@cost / 100.0) * changed / denom) if changed.positive?

      # 4) drawdown akun
      peak  = equity if equity > peak
      dd    = (peak - equity) / peak * 100
      maxdd = dd if dd > maxdd

      holdings = target
      prev_px  = target.index_with { |s| price_at(prices[s], d) }
    end
    Thread.current[:backtest_as_of] = nil

    build_report(equity, maxdd, period_rets, dates.length, cash_periods, benchmark_return(dates))
  ensure
    Thread.current[:backtest_as_of] = nil
    Thread.current[:regime_confirm_days] = nil
  end

  private

  # Simbol yang candle-nya kurang dari lookback+skip dibuang DIAM-DIAM oleh ranking
  # service. Kalau itu terjadi massal (mis. `ensure_data` masih mengunduh saat sweep
  # jalan, 2026-08-10), backtest tetap keluar angka — angka dari universe yang salah.
  # Gagal keras daripada menghasilkan kesimpulan palsu.
  #
  # Ambang diperketat 0,10 -> 0,02 (2026-09-16). Ambang 10% lama TIDAK menyala pada
  # run backtest 2026-08-26 yang memberi -6,78% untuk 365d/buffer-15, sementara run
  # berikutnya dengan parameter identik memberi +1,44%: selisih 8,2 poin persentase
  # dari cache candle yang masih tumbuh (517.066 -> 705.717 candle saham, +36%).
  # Artinya toleransi 10% cukup longgar untuk melewatkan kesalahan sebesar itu.
  # 2% masih memberi ruang untuk IPO baru (kondisi normal ~1%) tapi menangkap
  # universe pincang. Lihat docs/backtest-results.md.
  MAX_MISSING_SHARE = 0.02

  def check_coverage!(prices)
    return if prices.empty?

    need    = @lookback + @skip + 1
    missing = prices.count { |_, c| c.nil? || c.length < need }
    share   = missing.to_f / prices.size
    return if share <= MAX_MISSING_SHARE

    raise "Data tak lengkap: #{missing}/#{prices.size} simbol (#{(share * 100).round(1)}%) punya < #{need} candle 1d. " \
          "Jalankan ulang setelah fetch selesai — hasil dari universe pincang tidak sahih."
  end

  # Portofolio target tanggal d. Tanpa buffer: top_n murni. Dengan buffer: pertahankan
  # holding yang masih di top buffer_n (urut ranking), sisanya diisi dari top_n.
  def rank_at(date, holdings)
    n = @buffer_n.positive? ? @buffer_n : @top_n
    ranked = MomentumRankingService.new(
      as_of: date, symbols: @symbols, lookback: @lookback, skip: @skip, top_n: n,
      max_momentum: @max_momentum, min_price: @min_price, max_extension: @max_extension,
      # Feasibility posisi dihitung portfolio/top_n di ranking service. Minta n nama
      # tapi ukuran posisi tetap 1/top_n → skalakan portofolio supaya syaratnya identik
      # dengan jalur tanpa buffer (kalau tidak, buffer diam-diam melonggarkan filter).
      portfolio_idr: MomentumRankingService::PORTFOLIO_IDR * n / @top_n.to_f,
      residual: @residual, min_flow_ratio: @min_flow_ratio, max_flow_ratio: @max_flow_ratio
    ).call.map { |r| r[:symbol] }
    return ranked.first(@top_n) if @buffer_n.zero?

    keep = (ranked & holdings).first(@top_n)
    keep + (ranked.first(@top_n) - keep).first(@top_n - keep.size)
  end

  def build_report(equity, maxdd, period_rets, n_periods, cash_periods, benchmark)
    mean = period_rets.empty? ? 0.0 : period_rets.sum / period_rets.size
    var  = period_rets.empty? ? 0.0 : period_rets.sum { |r| (r - mean)**2 } / period_rets.size
    std  = Math.sqrt(var)
    # Sharpe per-periode dianualisasi (12 periode/tahun, rebalance ~bulanan).
    sharpe = std.zero? ? nil : (mean / std * Math.sqrt(12)).round(2)
    wins = period_rets.count(&:positive?)
    {
      total_return:  (equity - 100).round(2),
      benchmark:     benchmark,           # beli-tahan IHSG di window sama (%)
      alpha:         benchmark ? ((equity - 100) - benchmark).round(2) : nil,
      max_drawdown:  maxdd.round(2),
      sharpe:        sharpe,
      periods:       n_periods,
      win_rate:      period_rets.empty? ? 0.0 : (wins.to_f / period_rets.size * 100).round(1),
      cash_periods:  cash_periods,
      final_equity:  equity.round(2)
    }
  end

  def empty_report
    { total_return: 0.0, benchmark: nil, alpha: nil, max_drawdown: 0.0, sharpe: nil, periods: 0, win_rate: 0.0, cash_periods: 0, final_equity: 100.0 }
  end

  # Beli-tahan IHSG dari rebalance pertama ke terakhir (%), pembanding pasif.
  def benchmark_return(dates)
    ihsg = Candle.where(asset_type: "index", symbol: CALENDAR_SYM, timeframe: "1d").ordered.to_a
    first = price_at(ihsg, dates.first)
    last  = price_at(ihsg, dates.last)
    return nil if first.nil? || last.nil? || first.zero?
    ((last / first - 1.0) * 100).round(2)
  end

  # Close terakhir pada/atau sebelum tanggal d (saham bisa halt di hari tertentu).
  def price_at(candles, d)
    return nil if candles.nil?
    c = candles.reverse_each.find { |x| x.opened_at <= d }
    c&.close&.to_f
  end

  def rebalance_dates
    cal = Candle.where(asset_type: "index", symbol: CALENDAR_SYM, timeframe: "1d")
                .order(:opened_at).pluck(:opened_at)
    return [] if cal.empty?
    end_at = cal.last - @offset.days
    cutoff = end_at - @days.days
    window = cal.select { |d| d >= cutoff && d <= end_at }
    window.each_with_index.select { |_, i| (i % @rebalance).zero? }.map(&:first)
  end

  def load_prices
    @symbols.index_with do |sym|
      Candle.for_asset("stock").for_symbol(sym).for_timeframe("1d").ordered.to_a
    end
  end

  # Histori 1d dalam untuk tiap simbol + ^JKSE (regime & kalender rebalance).
  # Dulu meminjam BacktestService (dihapus bersama strategi per-trade); kini
  # dua metode fetch itu tinggal di sini, satu-satunya pemakainya.
  def ensure_data
    range = yahoo_range(cap_years: 5)
    @symbols.each { |s| ensure_tf(s, "1d", range) }
    ensure_index_history
  end

  # Rentang Yahoo ("2y"/"5y") yang cukup menutup window + offset, dibatasi cap_years.
  def yahoo_range(cap_years:)
    years = ((@days + @offset) / 365.0).ceil + 1
    "#{[ years, cap_years ].min}y"
  end

  def ensure_tf(symbol, timeframe, range)
    need_from = Time.current - (@days + @offset + @lookback + @skip + 30).days
    earliest  = Candle.for_asset("stock").for_symbol(symbol).for_timeframe(timeframe).minimum(:opened_at)
    return if earliest && earliest <= need_from

    rows = YahooFinanceClient.new.klines(symbol: symbol, interval: timeframe, limit: 5000, range: range)
    return if rows.blank?
    upsert_candles(symbol, timeframe, "stock", rows)
  rescue => e
    Rails.logger.warn("[MomentumBacktestService] fetch #{symbol}/#{timeframe}: #{e.message}")
  end

  def ensure_index_history
    sym       = CALENDAR_SYM
    need_from = Time.current - (@days + @offset + 90).days
    earliest  = Candle.where(asset_type: "index", symbol: sym, timeframe: "1d").minimum(:opened_at)
    return if earliest && earliest <= need_from

    rows = YahooFinanceClient.new.klines(symbol: sym, interval: "1d", limit: 5000,
                                         range: yahoo_range(cap_years: 5))
    return if rows.blank?
    upsert_candles(sym, "1d", "index", rows)
  rescue => e
    Rails.logger.warn("[MomentumBacktestService] fetch index: #{e.message}")
  end

  def upsert_candles(symbol, timeframe, asset_type, rows)
    records = rows.map do |k|
      {
        symbol: symbol, timeframe: timeframe, asset_type: asset_type,
        open: k[:open], high: k[:high], low: k[:low], close: k[:close], volume: k[:volume],
        opened_at: k[:opened_at], created_at: Time.current, updated_at: Time.current
      }
    end
    Candle.upsert_all(records, unique_by: [ :symbol, :timeframe, :opened_at ],
                               update_only: [ :open, :high, :low, :close, :volume, :asset_type ])
  end
end

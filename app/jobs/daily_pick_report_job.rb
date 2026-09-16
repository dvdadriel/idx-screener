# Rekomendasi saham HARIAN ke Telegram — dikirim tiap hari bursa, apa pun regimenya.
#
# Menggantikan RankReportJob (yang hanya bersuara saat komposisi top-10 berubah):
# job ini selalu mengirim, karena "hari ini tidak ada yang berubah" tetap informasi
# yang ingin dilihat. Saat regime risk-off daftarnya tetap dikirim — ditandai tegas
# sebagai WATCHLIST, bukan izin beli. Ranking adalah informasi; gate regime tetap
# berlaku di jalur aksi nyata (MomentumSnapshotJob / paper trading).
#
# Skor = persentil momentum di antara kandidat layak (MomentumRankingService#with_scores).
# Bukan model dan bukan prediksi — lihat komentar di sana sebelum menaikkan bobotnya.
class DailyPickReportJob < ApplicationJob
  queue_as :default

  TOP_N    = 10
  LAST_KEY = "daily_pick_report:last_symbols".freeze

  def perform(universe = "extended")
    symbols = TelegramCommandService::UNIVERSES[universe.to_s]&.call
    return Rails.logger.warn("[DailyPickReportJob] universe tak dikenal: #{universe}") unless symbols

    blocked = IdxMarketState.long_blocked?
    svc     = MomentumRankingService.new(symbols: symbols, top_n: TOP_N, ignore_regime: true)
    picks   = svc.call

    if picks.empty?
      Rails.logger.warn("[DailyPickReportJob] tak ada kandidat layak — laporan tak dikirim")
      return
    end

    previous = Array(Rails.cache.read(LAST_KEY))
    text     = build_message(picks, svc.eligible_count, blocked, previous)

    notifier = TelegramNotifier.new(asset_type: "stock")
    if notifier.send(:configured?)
      notifier.send(:post_message, text)
    else
      Rails.logger.info("[DailyPickReportJob] Telegram tak dikonfigurasi:\n#{text}")
    end

    Rails.cache.write(LAST_KEY, picks.map { |p| p[:symbol] }, expires_in: 30.days)
    picks
  end

  private

  def build_message(picks, eligible, blocked, previous)
    date  = Time.current.in_time_zone(IdxMarket::TZ).strftime("%d %b %Y")
    lines = [ "📊 *Rekomendasi Momentum IDX — #{date}*", "" ]
    lines.concat(regime_block(blocked))
    lines << ""

    flows = IdxForeignFlowService.flow_ratios(picks.map { |p| p[:symbol] })

    picks.each_with_index do |p, i|
      sym      = p[:symbol].sub(".JK", "")
      is_fresh = previous.any? && !previous.include?(p[:symbol])
      lines << "*#{i + 1}. #{sym}* — skor *#{p[:score]}*#{is_fresh ? ' 🆕' : ''}"
      lines << "   momentum `#{format('%+.1f%%', p[:momentum] * 100)}` · Rp #{p[:last_close].to_i}#{context(p, flows[p[:symbol]])}"
      # Level hanya untuk pick BARU: yang sudah dipegang tak butuh entry baru, dan
      # mengulanginya tiap hari membuat pesan panjang lalu berhenti dibaca.
      lines << levels_line(p[:symbol]) if is_fresh
    end

    lines << ""
    lines.concat(legend(picks, eligible, previous))
    lines.join("\n")
  end

  # Entry/SL/TP berbasis ATR (1,5x / 3x — R:R 1:2), pindahan dari kartu RankReportJob
  # yang digantikan job ini. Ini aturan posisi, BUKAN prediksi arah: dipakai untuk menentukan
  # ukuran risiko kalau pick diambil, bukan untuk meyakinkan bahwa ia akan naik.
  def levels_line(symbol)
    candles = Candle.for_asset("stock").for_symbol(symbol).for_timeframe("1d").ordered.last(60)
    return "" if candles.length < 15

    lv = IndicatorService.new(candles).atr_levels("BUY")
    return "" if lv.empty?

    "   entry `#{lv[:entry_price].to_i}` · SL `#{lv[:sl_price].to_i}` (#{lv[:sl_pct]}%) · " \
      "TP `#{lv[:tp_price].to_i}` (+#{lv[:tp_pct]}%)"
  end

  def regime_block(blocked)
    if blocked
      [ "🛑 *REGIME RISK-OFF — WATCHLIST, BUKAN SINYAL BELI*",
        "_#{IdxMarketState.reason}_",
        "_Portofolio sistem tetap CASH. Daftar di bawah untuk dipantau._" ]
    else
      [ "🟢 *REGIME RISK-ON* — _#{IdxMarketState.reason}_" ]
    end
  end

  # Konteks per saham. ATR% dan jarak ke MA20 memang dipakai sistem (volatilitas &
  # anti-chase); aliran dana asing TIDAK — ia ditempel sebagai informasi mentah dan
  # ditandai di legenda, karena gagal uji permutasi (p ~ 0,32).
  def context(pick, flow_ratio)
    candles = Candle.for_asset("stock").for_symbol(pick[:symbol]).for_timeframe("1d").ordered.last(60)
    parts   = []

    if candles.length >= 20
      ind  = IndicatorService.new(candles)
      ma20 = candles.last(20).sum { |c| c.close.to_f } / 20.0
      parts << "vs MA20 `#{format('%+.1f%%', (pick[:last_close] - ma20) / ma20 * 100)}`" if ma20.positive?
      parts << "ATR `#{ind.atr_pct.round(1)}%`" if ind.atr_pct
    end
    parts << "asing20d `#{format('%+.1f%%', flow_ratio * 100)}`" if flow_ratio

    parts.empty? ? "" : "\n   #{parts.join(' · ')}"
  end

  def legend(picks, eligible, previous)
    out = [ "_Skor = persentil momentum di antara #{eligible} saham layak_",
            "_(likuid ≥ Rp1M/hari, harga ≥ Rp100, bukan pump >100%/6bln)._",
            "_Peringkat kekuatan relatif — bukan prediksi harga._" ]
    out << "_asing20d = net lembar asing ÷ volume 20 hari. INFORMASI saja: overlay ini_"
    out << "_gagal uji permutasi (p≈0,32), jadi TIDAK ikut menentukan skor._"
    if previous.any?
      unchanged = (picks.map { |p| p[:symbol] } & previous).size
      out << "_#{unchanged}/#{picks.size} sama dengan kiriman terakhir._"
    end
    out
  end
end

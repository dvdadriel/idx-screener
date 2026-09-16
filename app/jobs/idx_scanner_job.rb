# Fetch candle harian (1d) seluruh universe IDX — fondasi data untuk momentum.
#
# Dulu job ini juga men-scan & menerbitkan sinyal SWING_PICK (IdxScannerService).
# Strategi itu DIHAPUS 2026-09-16: paper trading 270 trade menunjukkan win rate 40%
# dengan avg -0,38%/trade, dan tak pernah lolos validasi backtest. Yang tersisa —
# dan satu-satunya alasan job ini masih ada — adalah pengambilan candle-nya:
# StockPollerJob hanya jalan saat bursa buka, sedangkan momentum butuh histori 1d
# dalam (lookback 126 + skip 21 bar) yang di-refresh sekali sehari pasca-tutup.
class IdxScannerJob < ApplicationJob
  queue_as :scan

  # Di bawah ini, hasil fetch dianggap tidak layak dipakai (lihat akhir #perform).
  # 0,9 memberi ruang untuk saham suspend/delisting yang Yahoo memang tak punya —
  # produksi 2026-09-15 mencatat gagal 2/958 (99,8% cakupan).
  MIN_COVERAGE = 0.9

  def perform
    client = YahooFinanceClient.new
    universe = IdxUniverseService.all
    Rails.logger.info("[IdxScannerJob] Fetching #{universe.size} IDX tickers")

    failed = 0
    fetched = 0
    rate_limited = nil

    catch(:rate_limited) do
      universe.each_with_index do |symbol, i|
        begin
          rows = client.klines(symbol: symbol, interval: "1d", limit: 200)
          upsert(symbol, rows)
          fetched += 1
        rescue Http::RetryableError => e
          rate_limited = e.message
          Rails.logger.warn("[IdxScannerJob] aborting fetch (#{e.message})")
          throw :rate_limited
        rescue => e
          failed += 1
          Rails.logger.error("[IdxScannerJob] fetch #{symbol}: #{e.message}") if failed <= 20
        end

        # Throttle: 200ms between requests, extra 1s every 50 requests
        sleep 0.2
        sleep 1.0 if i.positive? && (i % 50).zero?
      end
    end

    coverage = universe.empty? ? 1.0 : fetched.to_f / universe.size
    Rails.logger.info(
      "[IdxScannerJob] Fetch complete. Berhasil: #{fetched}/#{universe.size} " \
      "(#{(coverage * 100).round(1)}%), gagal: #{failed}#{rate_limited ? ', DIHENTIKAN rate limit' : ''}"
    )

    # Rate limit dulu membatalkan fetch DIAM-DIAM: job tetap melapor "Fetch complete"
    # dan keluar sukses, jadi rantai harian lanjut membuat laporan di atas candle
    # kemarin tanpa satu pun alarm. Sekarang cakupan di bawah MIN_COVERAGE = gagal
    # keras, supaya rantai mencatatnya dan GitHub Actions merah.
    if coverage < MIN_COVERAGE
      raise "Fetch candle tak lengkap: #{fetched}/#{universe.size} " \
            "(#{(coverage * 100).round(1)}%, minimum #{(MIN_COVERAGE * 100).round}%)" \
            "#{rate_limited ? " — dihentikan rate limit: #{rate_limited}" : ''}"
    end

    fetched
  end

  private

  def upsert(symbol, rows)
    return if rows.empty?

    records = rows.map do |k|
      {
        symbol:     symbol,
        timeframe:  "1d",
        asset_type: "stock",
        open: k[:open], high: k[:high], low: k[:low], close: k[:close], volume: k[:volume],
        opened_at:  k[:opened_at],
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    Candle.upsert_all(
      records,
      unique_by: [ :symbol, :timeframe, :opened_at ],
      update_only: [ :open, :high, :low, :close, :volume, :asset_type ]
    )
  end
end

# MomentumPaperTracker dan PaperTradeStats itu perhitungan path-dependent
# (equity curve, rebalancing, drawdown, Sharpe) — bukan agregat SQL biasa.
# Reimplementasi sebagai Postgres view berisiko salah angka, jadi hasil Ruby
# yang sudah teruji ini di-materialize apa adanya ke tabel ringkasan, supaya
# dashboard statis (React + Supabase REST) bisa baca tanpa menjalankan Ruby.
class DashboardSummaryMaterializer
  ASSET_TYPES = %w[stock].freeze

  def call
    materialize_momentum
    ASSET_TYPES.each { |t| materialize_paper_stats(t) }
    refresh_latest_closes
  end

  private

  # latest_candle_closes adalah MATERIALIZED view (migrasi 20260916000007): versi
  # biasa memindai 577 ribu candle pada tiap kunjungan dashboard dan melewati
  # statement_timeout role anon di Supabase. Ia di-refresh di sini karena kelas
  # ini sudah menjadi langkah "snapshot" pada rantai idx:daily_close, tepat
  # setelah candle hari itu masuk.
  #
  # CONCURRENTLY supaya dashboard tidak blank selama refresh; ia butuh index unik,
  # yang dibuat oleh migrasi yang sama. Kegagalan di sini TIDAK boleh menjatuhkan
  # materialisasi momentum & paper stats yang sudah selesai di atasnya — cakupan
  # data basi jauh lebih ringan akibatnya daripada ekuitas yang tak ter-update.
  def refresh_latest_closes
    # REFRESH ... CONCURRENTLY DILARANG di dalam blok transaksi oleh Postgres, dan
    # `rescue` tidak menolong: begitu statement-nya ditolak, seluruh transaksi
    # jadi aborted dan setiap perintah berikutnya gagal dengan
    # PG::InFailedSqlTransaction. Ditemukan lewat 4 test yang tiba-tiba error
    # berantai, bukan lewat teori.
    #
    # Jalur produksi (rake idx:daily_close) tidak bertransaksi, jadi refresh jalan
    # normal di sana. Test membungkus tiap case dalam transaksi, jadi dilewati —
    # dan kalau suatu saat ada pemanggil produksi yang membungkusnya, baris log ini
    # yang akan memberitahu, bukan kegagalan senyap.
    if ActiveRecord::Base.connection.open_transactions.positive?
      Rails.logger.info("[DashboardSummaryMaterializer] lewati REFRESH latest_candle_closes — sedang di dalam transaksi")
      return
    end

    ActiveRecord::Base.connection.execute(
      "REFRESH MATERIALIZED VIEW CONCURRENTLY public.latest_candle_closes"
    )
  rescue => e
    Rails.logger.error("[DashboardSummaryMaterializer] refresh latest_candle_closes: #{e.class}: #{e.message}")
  end

  def materialize_momentum
    data = MomentumPaperTracker.new.call
    summary = MomentumTrackerSummary.first_or_initialize
    summary.update!(data: data.as_json)
  end

  def materialize_paper_stats(asset_type)
    data = PaperTradeStats.for(asset_type)
    summary = PaperTradeStatsSummary.find_or_initialize_by(asset_type: asset_type)
    summary.update!(data: serialize_stats(data))
  end

  def serialize_stats(data)
    data.merge(
      best_trade: trade_ref(data[:best_trade]),
      worst_trade: trade_ref(data[:worst_trade])
    ).as_json
  end

  def trade_ref(trade)
    return nil unless trade

    {
      symbol: trade.symbol,
      strategy: trade.strategy,
      pnl_pct: trade.pnl_pct&.to_f,
      exit_at: trade.exit_at
    }
  end
end

namespace :idx do
  desc "Refresh universe IDX (05:00 WIB) — dulu di config/recurring.yml"
  task universe_refresh: :environment do
    IdxUniverseService.refresh!
  end

  desc "Fetch candle 1d seluruh universe IDX (16:30 WIB) — fondasi data momentum"
  task scanner: :environment do
    IdxScannerJob.perform_now
  end

  desc "Rekam regime + top-10 momentum harian, forward tracking (17:00 WIB)"
  task snapshot: :environment do
    MomentumSnapshotJob.perform_now
    DashboardSummaryMaterializer.new.call
  end

  desc "Rekomendasi saham harian + skor — dikirim tiap hari bursa, apa pun regimenya"
  task daily_picks: :environment do
    DailyPickReportJob.perform_now("extended")
  end

  # Rantai penutupan harian. DIBUAT karena cron GitHub Actions tidak menjamin
  # urutan: `scanner` dijadwalkan 09:30 UTC tapi nyatanya jalan 14:23 dan 15:56 UTC
  # (telat 5-6 jam), sementara `snapshot` & laporan yang dijadwalkan 30-45
  # menit sesudahnya bisa jalan DULUAN dan memakai candle kemarin. Satu rantai
  # berurutan menghapus risiko itu sepenuhnya.
  #
  # Tiap langkah dibungkus rescue: kegagalan aliran dana asing tak boleh membatalkan
  # laporan, dan kegagalan laporan tak boleh membatalkan snapshot (bukti forward
  # tracking). Yang gagal dicatat dan dilaporkan di akhir.
  desc "Rantai penutupan harian: candle -> aliran asing -> snapshot -> laporan"
  task daily_close: :environment do
    failures = []

    {
      "candle 1d"    => -> { IdxScannerJob.perform_now },
      "aliran asing" => -> { Rake::Task["idx:foreign_flow_daily"].invoke },
      "snapshot"     => -> { MomentumSnapshotJob.perform_now; DashboardSummaryMaterializer.new.call },
      "laporan"      => -> { DailyPickReportJob.perform_now("extended") }
    }.each do |label, step|
      step.call
      puts "✓ #{label}"
    rescue => e
      failures << "#{label}: #{e.class}: #{e.message}"
      puts "✗ #{label} — #{e.class}: #{e.message}"
    end

    abort("Rantai harian gagal sebagian:\n  #{failures.join("\n  ")}") if failures.any?
  end

  desc "Digest Telegram harian: sinyal, P&L, win rate (17:00 WIB)"
  task daily_summary: :environment do
    DailySummaryJob.perform_now
  end

  desc "Backup tabel bukti forward-tracking (18:45 WIB)"
  task evidence_backup: :environment do
    EvidenceBackupJob.perform_now
  end

  desc "Hapus candle lewat retensi per timeframe (10:15 WIB)"
  task candle_prune: :environment do
    CandlePruneJob.perform_now
  end

  desc "Laporan mingguan trust-loop momentum (Jumat 17:30 WIB)"
  task weekly_report: :environment do
    MomentumWeeklyReportJob.perform_now
  end

  desc "Poll candle IDX (tiap 30 menit, skip kalau market tutup)"
  task poll: :environment do
    StockPollerJob.perform_now
  end

  desc "Update paper trade terbuka (tiap 5 menit)"
  task paper_trade_update: :environment do
    PaperTradeUpdaterJob.perform_now
  end

  desc "Watchdog data stale / worker mati (tiap 5 menit)"
  task health_monitor: :environment do
    HealthMonitorJob.perform_now
  end

  desc "Alert Telegram untuk job gagal baru (tiap 15 menit)"
  task failed_job_alert: :environment do
    FailedJobAlertJob.perform_now
  end
end

namespace :idx do
  desc "Ingest berkas Ringkasan Saham IDX (CSV/JSON). Contoh: bin/rails 'idx:foreign_flow_ingest[tmp/20260828.csv]'"
  task :foreign_flow_ingest, [ :path ] => :environment do |_t, args|
    abort "Butuh path berkas" if args[:path].blank?
    n = IdxForeignFlowService.ingest_file(args[:path])
    puts "Ingest #{n} baris dari #{args[:path]}. Total ForeignFlow: #{ForeignFlow.count}"
  end

  desc "Backfill aliran dana asing dari IDX mundur N hari. Contoh: bin/rails 'idx:foreign_flow_backfill[400]'"
  task :foreign_flow_backfill, [ :days ] => :environment do |_t, args|
    days  = (args[:days] || 400).to_i
    ok = failed = 0
    first_error = nil

    (0...days).each do |i|
      date = Date.current - i.days
      next if date.saturday? || date.sunday?
      next if ForeignFlow.where(traded_on: date).exists?

      begin
        ok += IdxForeignFlowService.fetch_day(date)
      rescue => e
        failed += 1
        first_error ||= "#{e.class}: #{e.message}"
        # Gagal beruntun sejak awal = akses diblokir, bukan satu hari libur.
        # Berhenti daripada menghabiskan ratusan request ke tembok yang sama.
        break if ok.zero? && failed >= 5
      end
      sleep 0.5
    end

    puts "Backfill selesai. Baris masuk: #{ok}. Hari gagal: #{failed}."
    if ok.zero?
      puts "GAGAL TOTAL — #{first_error}"
      puts "idx.co.id memblokir akses otomatis (Cloudflare). Pakai jalur berkas:"
      puts "  1. Buka https://www.idx.co.id/id/data-pasar/ringkasan-perdagangan/ringkasan-saham/"
      puts "  2. Unduh Ringkasan Saham per tanggal (CSV/XLSX -> simpan sebagai CSV)"
      puts "  3. bin/rails 'idx:foreign_flow_ingest[path/berkas.csv]'"
    end
  end

  desc "Tarik aliran dana asing hari ini (setelah bursa tutup)"
  task foreign_flow_daily: :environment do
    date = Date.current
    date -= 1 if Time.current.in_time_zone(IdxMarket::TZ).hour < 17
    next if date.saturday? || date.sunday?
    next if ForeignFlow.where(traded_on: date).exists?

    n = IdxForeignFlowService.fetch_day(date)
    puts "Aliran dana asing #{date}: #{n} baris"
  end

  desc "Status cakupan data aliran dana asing"
  task foreign_flow_status: :environment do
    n = ForeignFlow.count
    puts "Baris: #{n}"
    if n.positive?
      puts "Rentang: #{ForeignFlow.minimum(:traded_on)} .. #{ForeignFlow.maximum(:traded_on)}"
      puts "Simbol unik: #{ForeignFlow.distinct.count(:symbol)}"
      puts "Hari bursa unik: #{ForeignFlow.distinct.count(:traded_on)}"
    else
      puts "KOSONG — hipotesis smart money belum bisa diuji."
    end
  end
end

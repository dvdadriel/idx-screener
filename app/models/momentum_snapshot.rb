# Snapshot harian hasil MomentumRankingService — data forward-tracking untuk
# membuktikan (atau membantah) edge momentum. Satu baris per pick; hari risk-off
# dicatat satu baris marker (rank & symbol nil) supaya regime tetap terekam.
class MomentumSnapshot < ApplicationRecord
  scope :for_date, ->(d) { where(snapshot_date: d) }
  scope :picks,    -> { where.not(symbol: nil) }

  def self.snapshot_dates
    distinct.order(:snapshot_date).pluck(:snapshot_date)
  end

  def self.taken_for?(date)
    for_date(date).exists?
  end

  # Rekam satu hari: picks (Array dari MomentumRankingService) + regime. Dipakai
  # oleh MomentumSnapshotJob (hari ini, live) dan MomentumSnapshotBackfillService
  # (hari lampau, as-of) — satu sumber kebenaran format penyimpanan.
  # eligible_count: jumlah kandidat yang lolos seluruh filter kelayakan hari itu —
  # penyebut skor persentil. nil untuk baris lama (sebelum skor ada) dan untuk
  # backfill yang tak menyertakannya; view merender "—" bukan angka karangan.
  def self.record!(date:, picks:, regime:, eligible_count: nil)
    if picks.empty?
      create!(snapshot_date: date, regime: regime, eligible_count: eligible_count)
    else
      picks.each_with_index do |p, i|
        create!(snapshot_date: date, regime: regime, rank: i + 1,
               symbol: p[:symbol], momentum: p[:momentum], price: p[:last_close],
               score: p[:score], eligible_count: eligible_count)
      end
    end
  end
end

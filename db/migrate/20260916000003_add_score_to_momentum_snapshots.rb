class AddScoreToMomentumSnapshots < ActiveRecord::Migration[8.0]
  def change
    # Skor persentil dihitung MomentumRankingService terhadap SELURUH kandidat
    # layak hari itu. Disimpan, bukan dihitung ulang saat render: menghitungnya
    # berarti me-ranking ~960 simbol (memuat 148+ candle per simbol) pada setiap
    # kunjungan dashboard. eligible_count ikut disimpan karena skor tanpa
    # penyebutnya tak bisa dibaca — "96" hanya berarti sesuatu bila kita tahu
    # 96% dari berapa.
    add_column :momentum_snapshots, :score, :integer
    add_column :momentum_snapshots, :eligible_count, :integer
  end
end

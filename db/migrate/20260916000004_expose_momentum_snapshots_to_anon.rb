class ExposeMomentumSnapshotsToAnon < ActiveRecord::Migration[8.0]
  # Dashboard statis (React + Supabase REST di Vercel) perlu peringkat momentum
  # harian berikut skornya. Sebelum ini ia menampilkan SWING_PICK, strategi yang
  # sudah dihapus dari kode — jadi tabelnya kosong dan panel itu mati diam-diam.
  #
  # momentum_snapshots tak punya kolom asset_type: ia memang khusus saham IDX
  # (MomentumRankingService hanya berjalan di universe IDX), jadi USING (true)
  # benar di sini — sama alasannya dengan momentum_tracker_summaries.
  #
  # foreign_flows SENGAJA tidak dibuka: 312 ribu baris mentah yang hanya berguna
  # setelah diagregasi 20 hari per simbol, dan overlay-nya sendiri tak lolos uji
  # permutasi. Membukanya berarti mengirim data besar untuk angka yang kita
  # putuskan tidak dipakai.
  def up
    execute "GRANT SELECT ON public.momentum_snapshots TO anon;"
    execute <<~SQL
      CREATE POLICY anon_read_momentum_snapshots ON public.momentum_snapshots
        FOR SELECT TO anon USING (true);
    SQL
  end

  def down
    execute "DROP POLICY IF EXISTS anon_read_momentum_snapshots ON public.momentum_snapshots;"
    execute "REVOKE SELECT ON public.momentum_snapshots FROM anon;"
  end
end

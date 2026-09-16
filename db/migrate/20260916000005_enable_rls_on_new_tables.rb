class EnableRlsOnNewTables < ActiveRecord::Migration[8.0]
  # EnableRlsDefaultDeny (20260828120100) menyalakan RLS untuk semua tabel yang
  # ADA SAAT ITU. Tabel yang lahir sesudahnya tidak ikut — `foreign_flows`
  # (20260916000001) adalah kasus pertamanya, dan satu-satunya alasan ia tidak
  # bocor adalah role anon kebetulan tak pernah diberi GRANT ke sana.
  #
  # Itu keamanan yang bergantung pada kelalaian, bukan pada aturan. Di Postgres,
  # RLS tanpa policy berarti TOLAK SEMUA untuk role non-owner, jadi menyalakannya
  # tidak memutus apa pun: pemilik tabel (role migrasi) dan service_role tetap
  # lewat, dan anon memang tidak boleh menyentuhnya.
  #
  # Sengaja menyapu seluruh schema public, bukan menyebut satu tabel: migrasi
  # berikutnya yang menambah tabel akan tetap tertinggal kalau daftarnya manual.
  # Jalankan ulang kapan pun aman — sudah menyala akan dilewati.
  def up
    execute <<~SQL
      DO $$
      DECLARE r RECORD;
      BEGIN
        FOR r IN
          SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND c.relkind = 'r'
            AND NOT c.relrowsecurity
        LOOP
          EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.relname);
          RAISE NOTICE 'RLS dinyalakan: %', r.relname;
        END LOOP;
      END $$;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Sengaja tidak di-reverse: mematikan RLS lewat rollback membuka tabel produksi " \
      "ke anon tanpa disadari. Matikan manual per tabel kalau memang perlu."
  end
end

class MaterializeLatestCandleCloses < ActiveRecord::Migration[8.0]
  SELECT_SQL = <<~SQL.freeze
    SELECT DISTINCT ON (symbol, timeframe, asset_type)
           symbol, timeframe, asset_type, close, opened_at
    FROM candles
    WHERE asset_type = 'stock'
    ORDER BY symbol, timeframe, asset_type, opened_at DESC
  SQL

  # View biasa menjalankan DISTINCT ON atas SELURUH tabel candles pada setiap
  # kunjungan dashboard: 577 ribu baris dipindai untuk menghasilkan 1.841.
  # Index (migrasi 20260916000006) menghapus sort ke disk tapi tidak menolong
  # banyak — Postgres belum punya index skip scan, jadi seluruh entri tetap
  # dilewati. Terukur: 380 ms (seq scan + sort) vs 717 ms (index scan penuh).
  #
  # Di Supabase keduanya melewati statement_timeout role anon. Dashboard Vercel
  # menerima 57014 "canceling statement due to statement timeout" dan seksi
  # Cakupan data menampilkan "0 simbol" — datanya ada, query-nya yang tak selesai.
  #
  # Datanya berubah sekali sehari (pasca-tutup bursa) tapi dibaca setiap kali
  # halaman dibuka. Itu definisi kandidat materialized view. Ini juga pola yang
  # sudah dipilih repo ini untuk alasan yang sama — lihat DashboardSummaryMaterializer.
  #
  # Index unik wajib ada: tanpanya REFRESH MATERIALIZED VIEW CONCURRENTLY ditolak,
  # dan refresh non-concurrent mengunci view sehingga dashboard blank saat rantai
  # harian berjalan.
  def up
    execute "DROP VIEW IF EXISTS public.latest_candle_closes;"
    execute "CREATE MATERIALIZED VIEW public.latest_candle_closes AS #{SELECT_SQL};"
    execute <<~SQL
      CREATE UNIQUE INDEX index_latest_candle_closes_key
        ON public.latest_candle_closes (symbol, timeframe, asset_type);
    SQL
    execute "GRANT SELECT ON public.latest_candle_closes TO anon;"
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS public.latest_candle_closes;"
    execute "CREATE VIEW public.latest_candle_closes AS #{SELECT_SQL};"
    execute "GRANT SELECT ON public.latest_candle_closes TO anon;"
  end
end

class IndexCandlesForLatestCloses < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # View `latest_candle_closes` melakukan
  #   DISTINCT ON (symbol, timeframe, asset_type) ... ORDER BY ..., opened_at DESC
  # dan tak ada index yang cocok dengan urutan itu. Index unik yang ada
  # (symbol, timeframe, opened_at) tidak memuat asset_type di posisi ORDER BY,
  # jadi Postgres terpaksa Seq Scan lalu sort — terukur lokal: 314 ribu baris,
  # "external merge Disk: 12944kB", 380 ms pada 577 ribu candle.
  #
  # Di Supabase itu melewati statement_timeout role anon: dashboard Vercel
  # mendapat 57014 "canceling statement due to statement timeout" dan seksi
  # Cakupan data menampilkan "0 simbol" — bukan karena datanya tak ada, tapi
  # karena query-nya tak pernah selesai. Bug ini menunggu sejak view dibuat;
  # ia baru muncul setelah tabel candle tumbuh cukup besar.
  #
  # Urutan kolom PENTING dan tidak intuitif. Percobaan pertama memakai
  # (symbol, timeframe, asset_type, opened_at DESC) dan planner MENGABAIKANNYA —
  # tetap Seq Scan. Sebabnya terlihat di Sort Key rencana eksekusi:
  # "candles.symbol, candles.opened_at DESC" — predikat asset_type dan timeframe
  # sudah didorong ke dalam view, jadi keduanya konstan dan harus berada di DEPAN
  # index sebagai kolom kesetaraan, baru diikuti kolom pengurutan.
  #
  # Partial index: view-nya sendiri sudah memfilter asset_type = 'stock', jadi
  # tak ada gunanya mengindeks baris crypto lama.
  def up
    add_index :candles,
              [ :asset_type, :timeframe, :symbol, :opened_at ],
              order: { opened_at: :desc },
              where: "asset_type = 'stock'",
              name: "index_candles_latest_close_lookup",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :candles, name: "index_candles_latest_close_lookup",
                           algorithm: :concurrently, if_exists: true
  end
end

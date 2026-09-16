class AddVolumeToForeignFlows < ActiveRecord::Migration[8.0]
  def change
    # ForeignBuy/ForeignSell IDX bersatuan LEMBAR SAHAM, bukan rupiah — ditemukan
    # saat validasi: BBCA 2026-09-15 ForeignBuy=65.949.600 sementara Value-nya
    # Rp 614 miliar. Rasio aliran asing karenanya harus dibandingkan dengan VOLUME
    # (lembar), bukan turnover (rupiah). Kolom volume ditambahkan untuk itu;
    # turnover (Rp) tetap disimpan karena dipakai filter likuiditas & VWAP.
    add_column :foreign_flows, :volume, :decimal, precision: 22, scale: 2
  end
end

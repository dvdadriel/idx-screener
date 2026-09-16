class CreateForeignFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :foreign_flows do |t|
      t.string  :symbol, null: false                    # "BBCA.JK" — sama dengan Candle
      t.date    :traded_on, null: false                 # tanggal bursa
      t.decimal :foreign_buy,  precision: 22, scale: 2   # nilai beli asing (Rp)
      t.decimal :foreign_sell, precision: 22, scale: 2   # nilai jual asing (Rp)
      t.decimal :foreign_net,  precision: 22, scale: 2, null: false   # buy - sell (Rp)
      t.decimal :turnover,     precision: 22, scale: 2   # nilai transaksi total hari itu (Rp)
      t.string  :source, null: false, default: "idx"     # asal data (audit trail)

      t.timestamps
    end

    add_index :foreign_flows, [ :symbol, :traded_on ], unique: true
    add_index :foreign_flows, :traded_on
  end
end

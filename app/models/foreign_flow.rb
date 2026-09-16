# Aliran dana asing harian per saham (IDX "Ringkasan Saham").
#
# Terpisah penuh dari Candle — sengaja. Candle adalah data harga dari Yahoo dan
# sudah jadi fondasi momentum; mencampur aliran dana ke sana berarti satu sumber
# rusak menjatuhkan keduanya. Tabel ini boleh bolong tanpa mengganggu apa pun.
class ForeignFlow < ApplicationRecord
  validates :symbol, :traded_on, :foreign_net, presence: true
  validates :symbol, uniqueness: { scope: :traded_on }

  scope :for_symbol, ->(sym) { where(symbol: sym) }
  scope :upto,       ->(date) { date ? where("traded_on <= ?", date) : all }
  scope :ordered,    -> { order(traded_on: :asc) }
end

require "test_helper"

class IdxForeignFlowServiceTest < ActiveSupport::TestCase
  def flow(symbol:, date:, net:, volume:)
    ForeignFlow.create!(symbol: symbol, traded_on: date, foreign_net: net, volume: volume)
  end

  # Rasio = Σ net lembar asing / Σ volume lembar pada `window` hari terakhir.
  test "flow_ratio menormalkan net flow terhadap volume" do
    20.times { |i| flow(symbol: "AAA.JK", date: Date.new(2026, 1, 1) + i, net: 10, volume: 100) }
    assert_in_delta 0.1, IdxForeignFlowService.flow_ratio("AAA.JK", window: 20), 1e-6
  end

  # nil = "tak tahu", bukan 0 = "netral". Membedakannya mencegah filter membuang
  # saham hanya karena datanya belum masuk.
  test "flow_ratio nil kalau data kurang dari window" do
    19.times { |i| flow(symbol: "BBB.JK", date: Date.new(2026, 1, 1) + i, net: 10, volume: 100) }
    assert_nil IdxForeignFlowService.flow_ratio("BBB.JK", window: 20)
  end

  test "flow_ratio menghormati as_of — tanpa lookahead" do
    # 20 hari pertama net -10, lalu 20 hari net +10. as_of di hari ke-20 hanya
    # boleh melihat yang negatif.
    20.times { |i| flow(symbol: "CCC.JK", date: Date.new(2026, 1, 1) + i, net: -10, volume: 100) }
    20.times { |i| flow(symbol: "CCC.JK", date: Date.new(2026, 2, 1) + i, net: 10, volume: 100) }

    assert_in_delta(-0.1, IdxForeignFlowService.flow_ratio("CCC.JK", as_of: Date.new(2026, 1, 20), window: 20), 1e-6)
    assert_in_delta(0.1,  IdxForeignFlowService.flow_ratio("CCC.JK", window: 20), 1e-6)
  end

  test "flow_ratios batch setara dengan pemanggilan satu per satu" do
    20.times { |i| flow(symbol: "AAA.JK", date: Date.new(2026, 1, 1) + i, net: 10, volume: 100) }
    20.times { |i| flow(symbol: "DDD.JK", date: Date.new(2026, 1, 1) + i, net: -5, volume: 100) }

    batch = IdxForeignFlowService.flow_ratios(%w[AAA.JK DDD.JK EEE.JK], window: 20)
    assert_in_delta 0.1,   batch["AAA.JK"], 1e-6
    assert_in_delta(-0.05, batch["DDD.JK"], 1e-6)
    assert_nil batch["EEE.JK"]   # tak ada data → tak muncul
  end

  # CSV ekspor IDX Indonesia: pemisah ribuan titik, desimal koma.
  test "parse_csv membaca angka format Indonesia dan menambahkan sufiks .JK" do
    csv = "StockCode,Date,ForeignBuy,ForeignSell,Volume,Value\n" \
          "BBCA,2026-08-28,\"1.500.000\",\"500.000\",\"4.000.000\",\"9.000.000\"\n"
    rows = IdxForeignFlowService.parse_csv(csv)

    assert_equal 1, rows.size
    assert_equal "BBCA.JK", rows.first[:symbol]
    assert_equal Date.new(2026, 8, 28), rows.first[:traded_on]
    assert_in_delta 1_000_000.0, rows.first[:foreign_net], 0.01
    assert_in_delta 4_000_000.0, rows.first[:volume], 0.01
    assert_in_delta 9_000_000.0, rows.first[:turnover], 0.01
  end

  # REGRESI SATUAN. ForeignBuy/Sell IDX = LEMBAR, Value = RUPIAH. Versi pertama
  # membagi lembar dengan rupiah dan memberi rasio ~0,000 untuk semua saham —
  # kecil, seragam, dan nyaris lolos sebagai "sinyal lemah". Angka di bawah persis
  # baris BBCA 2026-09-15 dari API IDX.
  test "flow_ratio memakai volume (lembar), bukan turnover (rupiah)" do
    20.times do |i|
      ForeignFlow.create!(symbol: "BBCA.JK", traded_on: Date.new(2026, 1, 1) + i,
                          foreign_buy: 65_949_600, foreign_sell: 71_222_300,
                          foreign_net: -5_272_700, volume: 95_608_200,
                          turnover: 614_491_297_500)
    end

    ratio = IdxForeignFlowService.flow_ratio("BBCA.JK", window: 20)
    assert_in_delta(-0.0551, ratio, 1e-4)   # -5,5% dari volume — bukan -0,0000086
    assert_operator ratio.abs, :>, 0.001, "rasio berbasis rupiah akan ~1e-5 di sini"
  end

  # Baris tanpa tanggal yang bisa dibaca dibuang, tidak ditebak: satu tanggal
  # salah menggeser seluruh jendela 20 hari tanpa terlihat di hasil akhir.
  test "extract membuang baris tanpa tanggal dan tanpa kode" do
    rows = IdxForeignFlowService.extract(
      [ { "StockCode" => "BBCA", "ForeignBuy" => 1, "ForeignSell" => 0 },            # tanpa tanggal
        { "Date" => "2026-08-28", "ForeignBuy" => 1, "ForeignSell" => 0 },           # tanpa kode
        { "StockCode" => "TLKM", "Date" => "2026-08-28", "ForeignBuy" => 5, "ForeignSell" => 2 } ],
      nil
    )
    assert_equal [ "TLKM.JK" ], rows.map { |r| r[:symbol] }
  end

  # Overlay tidak boleh membuang saham yang datanya belum di-ingest.
  test "MomentumRankingService#passes_flow? meloloskan simbol tanpa data" do
    svc = MomentumRankingService.new(symbols: [ "ZZZ.JK" ], min_flow_ratio: 0.0)
    assert svc.send(:passes_flow?, "ZZZ.JK")
  end

  test "MomentumRankingService#passes_flow? membuang aliran asing negatif" do
    20.times { |i| flow(symbol: "DDD.JK", date: Date.new(2026, 1, 1) + i, net: -5, volume: 100) }
    svc = MomentumRankingService.new(symbols: [ "DDD.JK" ], min_flow_ratio: 0.0)
    assert_not svc.send(:passes_flow?, "DDD.JK")
  end
end

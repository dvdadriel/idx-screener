require "test_helper"

class DailyPickReportJobTest < ActiveSupport::TestCase
  def pick(sym, mom, score, close = 1000)
    { symbol: sym, momentum: mom, score: score, last_close: close }
  end

  def build_msg(picks:, eligible: 50, blocked: false, previous: [])
    DailyPickReportJob.new.send(:build_message, picks, eligible, blocked, previous)
  end

  # Inti permintaan: daftar TETAP dikirim saat risk-off, tapi tak boleh terbaca
  # sebagai ajakan beli.
  test "risk-off tetap mengirim daftar tapi ditandai watchlist" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.15, 100) ], blocked: true)

    assert_includes msg, "BBCA"
    assert_includes msg, "WATCHLIST"
    assert_includes msg, "BUKAN SINYAL BELI"
    assert_includes msg, "CASH"
  end

  test "risk-on ditandai berbeda dan tanpa peringatan watchlist" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.15, 100) ], blocked: false)

    assert_includes msg, "RISK-ON"
    assert_not_includes msg, "BUKAN SINYAL BELI"
  end

  test "skor dan momentum tampil untuk tiap pick" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.152, 98, 9500), pick("TLKM.JK", -0.04, 41, 2750) ])

    assert_includes msg, "skor *98*"
    assert_includes msg, "+15.2%"
    assert_includes msg, "Rp 9500"
    assert_includes msg, "skor *41*"
    assert_includes msg, "-4.0%"
  end

  # Penyebut skor harus ikut disebut — "skor 96" tanpa "dari sekian" adalah angka gaib.
  test "legenda menyebut jumlah kandidat layak" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.15, 100) ], eligible: 103)
    assert_includes msg, "103 saham layak"
    assert_includes msg, "bukan prediksi"
  end

  # Aliran dana asing gagal uji permutasi; laporan wajib mengatakannya supaya
  # angka itu tak dibaca sebagai bagian dari skor.
  test "legenda menyatakan aliran asing tidak menentukan skor" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.15, 100) ])
    assert_includes msg, "TIDAK ikut menentukan skor"
  end

  test "pick baru ditandai, yang lama tidak" do
    picks = [ pick("BBCA.JK", 0.15, 100), pick("TLKM.JK", 0.10, 90) ]
    msg   = build_msg(picks: picks, previous: [ "BBCA.JK" ])

    assert_match(/TLKM\*.*🆕/, msg)
    assert_no_match(/BBCA\*.*🆕/, msg)
    assert_includes msg, "1/2 sama dengan kiriman terakhir"
  end

  # Kiriman pertama (belum ada riwayat) tak boleh menandai SEMUANYA baru.
  test "tanpa riwayat tak ada penanda baru" do
    msg = build_msg(picks: [ pick("BBCA.JK", 0.15, 100) ], previous: [])
    assert_not_includes msg, "🆕"
  end
end

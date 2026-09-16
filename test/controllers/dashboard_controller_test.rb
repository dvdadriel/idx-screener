require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # Tab crypto/saham dihapus bersama redesign: crypto mati (CRYPTO_ENABLED false)
  # dan satu panel tak membutuhkan tab. Yang diuji sekarang adalah struktur yang
  # menggantikannya, bukan struktur yang sudah tidak ada.
  test "merender dashboard instrumen tanpa sisa tab lama" do
    get root_path

    assert_response :success
    assert_select "[data-tab-name]", false, "tab lama harus hilang bersama panel crypto"
    assert_select "header.bar .wordmark", text: "IDXSCREENER"
    assert_select "section[aria-labelledby=?] .rail .rail-cell", "state-h", minimum: 5
    assert_select "section[aria-labelledby=?]", "rank-h"
  end

  # Regime adalah fakta pertama di halaman. Kalau ia hilang, setiap angka di
  # bawahnya kehilangan konteks pengambilannya.
  test "regime tampil di bar sebagai kata, bukan hanya warna" do
    get root_path

    assert_select "header.bar .chip" do |els|
      assert_match(/RISK-(ON|OFF)/, els.first.text)
    end
  end

  # Status bukti harus terbaca tanpa warna — dipakai di layar greyscale,
  # screenshot, dan oleh pembaca dengan defisiensi warna.
  test "legenda status bukti memakai glyph, bukan hanya warna" do
    get root_path

    assert_includes @response.body, "● tervalidasi"
    assert_includes @response.body, "◐ observasi"
    assert_includes @response.body, "○ gagal uji"
  end

  # Anti-slop: penanda yang dihapus tidak boleh menyelinap kembali lewat partial
  # atau helper mana pun. Lebih murah dijaga test daripada ditemukan lagi nanti.
  test "tidak ada emoji, gradien, atau glow di markup" do
    get root_path
    body = @response.body

    assert_no_match(/gradient/i, body, "gradien dilarang oleh DESIGN.md")
    assert_no_match(/glow-/, body, "glow shadow dilarang oleh DESIGN.md")
    assert_no_match(/rounded-2xl/, body, "grid kartu seragam sudah dihapus")
    assert_no_match(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/, body, "emoji sebagai ikon dilarang")
  end
end

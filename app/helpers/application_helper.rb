module ApplicationHelper
  # Angka gaya Indonesia: titik sebagai pemisah ribuan. Seluruh antarmuka
  # berbahasa Indonesia, jadi "13,041" salah baca — itu tiga belas koma nol
  # empat satu bagi pembaca di sini.
  def num(value)
    number_with_delimiter(value, delimiter: ".")
  end

  # Angka bertanda untuk nilai yang arahnya bermakna. Nol tidak diberi tanda:
  # "+0,0%" menyiratkan kenaikan yang tidak terjadi. Minus memakai U+2212
  # (tanda minus sungguhan), bukan hyphen, supaya sejajar dengan digit tabular.
  def signed_pct(value, decimals: 2)
    return "—" if value.nil?

    v = value.to_f.round(decimals)
    return "0#{decimal_tail(0.0, decimals)}%" if v.zero?

    "#{v.negative? ? "−" : "+"}#{format("%.#{decimals}f", v.abs).tr(".", ",")}%"
  end

  # Desimal gaya Indonesia, dengan U+2212 untuk negatif supaya lebar tandanya
  # sejajar dengan digit tabular di kolom angka.
  def dec(value)
    return "—" if value.nil?
    value.to_s.tr("-", "−").tr(".", ",")
  end

  # Jarak waktu dalam Bahasa Indonesia. Rails `time_ago_in_words` selalu keluar
  # Inggris di sini (tak ada locale :id terpasang), dan "diunggah 4 months lalu"
  # di halaman berbahasa Indonesia terbaca seperti bug. Cukup kasar — pembaca
  # butuh "kira-kira kapan", bukan presisi detik.
  def ago(time)
    return "—" if time.nil?

    secs = (Time.current - time).to_i
    return "baru saja" if secs < 60

    mins = secs / 60
    return "#{mins} menit lalu" if mins < 60

    hours = mins / 60
    return "#{hours} jam lalu" if hours < 24

    days = hours / 24
    return "#{days} hari lalu" if days < 30

    months = days / 30
    months < 12 ? "#{months} bulan lalu" : "#{months / 12} tahun lalu"
  end

  # Kelas arah. nil dan nol sama-sama netral — nol bukan kenaikan.
  def dir_class(value)
    return "ink" if value.nil? || value.to_f.zero?
    value.to_f.negative? ? "fall" : "rise"
  end

  private

  def decimal_tail(_value, decimals)
    decimals.positive? ? ",#{"0" * decimals}" : ""
  end
end

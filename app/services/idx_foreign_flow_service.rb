require "csv"
require "json"

# Ingest + metrik aliran dana asing IDX ("Ringkasan Saham" harian).
#
# === Kenapa tidak langsung fetch dari idx.co.id ===
# Per 2026-09-16 seluruh domain idx.co.id mengembalikan HTTP 403 dari Cloudflare
# ("Attention Required" — firewall rule, bukan JS challenge) untuk SEMUA endpoint,
# termasuk yang sudah dipakai IdxUniverseService. Header browser lengkap tidak
# menembusnya. Jadi `fetch_day` disediakan dan otomatis dipakai kalau akses pulih,
# tapi jalur yang BISA diandalkan sekarang adalah ingest berkas:
#
#   bin/rails 'idx:foreign_flow_ingest[/path/ke/berkas]'
#
# Berkas boleh CSV (ekspor "Ringkasan Saham" dari situs IDX) atau JSON (respons
# mentah endpoint GetStockSummary yang disimpan dari browser). Pola sama dengan
# storage/idx_universe.txt: sumber manual menang, jaringan sekadar kemudahan.
class IdxForeignFlowService
  API_URL = "https://www.idx.co.id/primary/TradingSummary/GetStockSummary".freeze

  # Nama kolom IDX -> field kita. IDX pernah mengganti penamaan; daftar ini memuat
  # varian yang diketahui supaya satu rename tidak mematikan ingest diam-diam.
  #
  # PENTING — SATUAN. ForeignBuy/ForeignSell IDX adalah LEMBAR SAHAM, bukan rupiah.
  # Contoh nyata (BBCA, 2026-09-15): ForeignBuy 65.949.600 sementara Value hari itu
  # Rp 614.491.297.500 dan Volume 95.608.200 lembar. 65,9 juta jelas sebanding
  # dengan Volume, bukan dengan Value. Versi pertama service ini membandingkan
  # lembar dengan rupiah dan menghasilkan rasio ~0,000 untuk SEMUA saham — angka
  # yang terlihat "kecil tapi masuk akal" dan nyaris lolos. Karena itu rasio
  # dihitung terhadap VOLUME (lembar lawan lembar), bukan turnover.
  FIELD_ALIASES = {
    symbol:       %w[StockCode Kode KodeSaham Code],
    foreign_buy:  %w[ForeignBuy ForeignBuyVal PembelianAsing],   # LEMBAR
    foreign_sell: %w[ForeignSell ForeignSellVal PenjualanAsing], # LEMBAR
    volume:       %w[Volume VolumeSaham],                        # LEMBAR
    turnover:     %w[Value NilaiTransaksi Nilai Turnover]        # RUPIAH
  }.freeze

  class IngestError < StandardError; end

  # === METRIK ===
  # Satu angka per saham: Σ net lembar asing / Σ volume, pada `window` hari terakhir.
  # Lembar dibagi lembar — tak ada asumsi harga, dan saham besar/kecil jadi
  # sebanding. +0,10 berarti selama 20 hari itu asing menyerap bersih 10% dari
  # seluruh lembar yang diperdagangkan.
  #
  # Return nil (BUKAN 0) kalau data tak cukup: nil = "tak tahu", 0 = "netral".
  # Membedakan keduanya penting — filter tak boleh membuang saham hanya karena
  # datanya belum masuk.
  def self.flow_ratio(symbol, as_of: nil, window: 20)
    rows = ForeignFlow.for_symbol(symbol).upto(as_of).ordered.last(window)
    return nil if rows.length < window

    volume = rows.sum { |r| r.volume.to_f }
    return nil if volume <= 0

    (rows.sum { |r| r.foreign_net.to_f } / volume).round(6)
  end

  # Versi batch — satu query untuk banyak simbol (backtest memanggil ini ribuan
  # kali; satu query per simbol per tanggal akan membuatnya tak selesai).
  def self.flow_ratios(symbols, as_of: nil, window: 20)
    rows = ForeignFlow.where(symbol: symbols).upto(as_of).ordered
                      .pluck(:symbol, :foreign_net, :volume)
    rows.group_by(&:first).each_with_object({}) do |(sym, all), out|
      last = all.last(window)
      next if last.length < window
      volume = last.sum { |_, _, v| v.to_f }
      next if volume <= 0
      out[sym] = (last.sum { |_, n, _| n.to_f } / volume).round(6)
    end
  end

  # === INGEST ===
  def self.ingest_file(path)
    raise IngestError, "Berkas tak ada: #{path}" unless File.exist?(path)

    raw = File.read(path)
    rows = path.end_with?(".json") ? parse_json(raw) : parse_csv(raw)
    raise IngestError, "Tak ada baris yang bisa dibaca dari #{path}" if rows.empty?

    upsert(rows)
  end

  # Fetch satu tanggal dari IDX. Saat ini selalu gagal (Cloudflare 403) — dibiarkan
  # supaya begitu akses pulih tak ada yang perlu ditulis ulang. Gagal = raise, bukan
  # diam: ingest yang diam-diam kosong lebih berbahaya daripada job yang merah.
  def self.fetch_day(date)
    body = Http.get_json(
      API_URL,
      query: { length: 1000, start: 0, date: date.strftime("%Y%m%d") },
      headers: {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/537.36",
        "Accept"     => "application/json",
        "Referer"    => "https://www.idx.co.id/id/data-pasar/ringkasan-perdagangan/ringkasan-saham/"
      },
      read_timeout: 30
    )
    rows = extract(body["data"] || [], date)
    raise IngestError, "IDX mengembalikan 0 baris untuk #{date}" if rows.empty?
    upsert(rows)
  end

  def self.parse_json(raw)
    body = JSON.parse(raw)
    data = body.is_a?(Hash) ? (body["data"] || []) : Array(body)
    extract(data, nil)
  end

  def self.parse_csv(raw)
    table = CSV.parse(raw, headers: true)
    extract(table.map(&:to_h), nil)
  end

  # Ubah baris mentah IDX -> atribut kita. Baris yang tanggalnya atau kodenya tak
  # terbaca DIBUANG, tidak ditebak: satu tanggal salah menggeser seluruh metrik
  # 20-hari dan tak akan terlihat di hasil akhir.
  def self.extract(data, fallback_date)
    data.filter_map do |row|
      code = pick(row, :symbol).to_s.strip.upcase
      next if code.empty?

      date = parse_date(row) || fallback_date
      next if date.nil?

      buy  = to_num(pick(row, :foreign_buy))
      sell = to_num(pick(row, :foreign_sell))
      next if buy.nil? && sell.nil?

      {
        symbol:       code.end_with?(".JK") ? code : "#{code}.JK",
        traded_on:    date,
        foreign_buy:  buy,
        foreign_sell: sell,
        foreign_net:  buy.to_f - sell.to_f,
        volume:       to_num(pick(row, :volume)),
        turnover:     to_num(pick(row, :turnover)),
        source:       "idx",
        created_at:   Time.current,
        updated_at:   Time.current
      }
    end
  end

  def self.pick(row, field)
    FIELD_ALIASES.fetch(field).each do |key|
      return row[key] if row.key?(key)
    end
    nil
  end

  def self.parse_date(row)
    raw = row["Date"] || row["Tanggal"] || row["TradeDate"]
    return nil if raw.blank?
    Date.parse(raw.to_s)
  rescue Date::Error
    nil
  end

  # IDX memakai pemisah ribuan dan koma desimal di ekspor CSV Indonesia.
  def self.to_num(v)
    return nil if v.nil?
    return v.to_f if v.is_a?(Numeric)
    s = v.to_s.strip.delete(" ")
    return nil if s.empty? || s == "-"
    s = s.tr(".", "").tr(",", ".") if s.match?(/\d\.\d{3}(\D|$)/)
    Float(s.delete(","))
  rescue ArgumentError
    nil
  end

  def self.upsert(rows)
    ForeignFlow.upsert_all(
      rows, unique_by: [ :symbol, :traded_on ],
      update_only: [ :foreign_buy, :foreign_sell, :foreign_net, :volume, :turnover, :source ]
    )
    rows.size
  end
end

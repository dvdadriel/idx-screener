# Metrik risiko dari deret pnl_pct per trade (urut waktu exit).
# Dipakai PaperTradeStats (paper trading live).
module RiskMetrics
  module_function

  # pnls:  Array<Float> pnl_pct per closed trade, urut waktu exit.
  # dates: Array<Date/Time> tanggal exit sejajar `pnls` (opsional).
  #
  #  - profit_factor = Σgain / |Σloss| (>1 = +EV). nil kalau belum ada loss.
  #  - max_drawdown  = penurunan puncak-ke-lembah kurva ekuitas ber-compound (%).
  #  - sharpe        = mean/stdev per-trade (BUKAN annualized — tak ada asumsi frekuensi).
  #
  # === Kenapa dua kali diperbaiki ===
  #
  # v1 (salah): cum += p — menjumlahkan pnl_pct secara ARITMETIK. Itu bukan
  # drawdown; hasilnya menembus -100% (dashboard menampilkan -4152,12%) dan tumbuh
  # mengikuti JUMLAH trade, bukan kerugian akun.
  #
  # v2 (masih salah): equity *= (1 + p/100) berurutan, satu trade = seluruh modal.
  # Bounded, tapi memodelkan hal yang tidak terjadi: data paper punya 13.041 trade
  # tutup dalam 61 hari bursa (~214 trade/hari) — posisinya PARALEL, bukan antre.
  # Compounding berurutan menjadikan avg -0,28%/trade sebagai (1-0,0028)^13041 ≈ 0,
  # jadi drawdown selalu mentok 100%: angka yang benar rumusnya tapi menjawab
  # pertanyaan yang salah.
  #
  # v3 (sekarang): kurva ekuitas HARIAN. Trade yang tutup di hari sama dirata-rata
  # (proxy portofolio equal-weight untuk posisi yang berjalan bersamaan), lalu
  # antar-hari di-compound. Ini yang dialami akun: satu hari = satu periode.
  #
  # Tanpa `dates` (pemanggil lama) tetap pakai compounding berurutan — benar untuk
  # backtest per-trade yang memang satu posisi pada satu waktu.
  def compute(pnls, dates: nil)
    return { profit_factor: nil, max_drawdown: nil, sharpe: nil } if pnls.empty?

    gain = pnls.select(&:positive?).sum
    loss = pnls.select(&:negative?).sum.abs
    profit_factor = loss.zero? ? nil : (gain / loss).round(2)

    n    = pnls.size
    mean = pnls.sum / n
    var  = pnls.sum { |p| (p - mean)**2 } / n
    std  = Math.sqrt(var)

    {
      profit_factor: profit_factor,
      max_drawdown:  max_drawdown(period_returns(pnls, dates)),
      sharpe:        std.zero? ? nil : (mean / std).round(2)
    }
  end

  # Return per PERIODE. Dengan tanggal: rata-rata pnl semua trade yang tutup di hari
  # yang sama (equal weight). Tanpa tanggal: tiap trade = satu periode.
  #
  # exit_at BISA nil pada trade yang sudah punya pnl_pct (ditemukan oleh test, bukan
  # teori). Trade begitu tak punya tempat di sumbu waktu, jadi dibuang dari kurva
  # ekuitas — bukan dipaksa masuk ke satu bucket palsu yang akan mengarang drawdown.
  # Kalau SEMUA tanggal nil, tak ada kurva harian yang bisa disusun → jatuh kembali
  # ke satu-trade-satu-periode, perilaku pemanggil tanpa `dates`.
  def period_returns(pnls, dates)
    return pnls if dates.nil? || dates.length != pnls.length

    dated = pnls.zip(dates).reject { |_, d| d.nil? }
    return pnls if dated.empty?

    dated.group_by { |_, d| d.to_date }
         .sort_by(&:first)
         .map { |_, rows| rows.sum { |p, _| p } / rows.size.to_f }
  end

  def max_drawdown(period_rets)
    equity = 1.0
    peak   = 1.0
    maxdd  = 0.0
    period_rets.each do |r|
      # Guard: return <= -100% (data rusak) membuat equity nol/negatif dan seluruh
      # deret sesudahnya tak bermakna. Jepit di -100% = modal habis.
      equity *= (1 + [ r, -100.0 ].max / 100.0)
      return 100.0 if equity <= 0
      peak  = equity if equity > peak
      dd    = (peak - equity) / peak * 100
      maxdd = dd if dd > maxdd
    end
    maxdd.round(2)
  end
end

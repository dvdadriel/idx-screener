# Hasil Backtest

**Dijalankan:** 2026-08-26
**Universe:** 223 simbol saham IDX (`EXTENDED_WATCHLIST`, ≈KOMPAS100), benchmark `^JKSE`
**Strategi:** cross-sectional momentum, rebalance bulanan, top-10
**Biaya:** fee 0,4% round-trip (khas IDX)

Semua angka di bawah adalah hasil **backtest dan paper trading**, bukan eksekusi dengan uang sungguhan. Baca [bagian batasan](#batasan--baca-bagian-ini) sebelum menyimpulkan apa pun.

## Walk-forward: jendela × buffer zone

`buffer` menahan posisi sampai keluar dari peringkat top-N yang lebih longgar, untuk menekan turnover. `off` berarti rebalance ketat ke top-10 tiap bulan.

| Window | Buffer | Return | Alpha vs IHSG | Max DD | Sharpe |
|---|---|---|---|---|---|
| 365d | off | −3,98% | +16,31% | 11,85% | −0,03 |
| 365d | 12 | +0,42% | +20,71% | 8,61% | 0,45 |
| 365d | 15 | +1,44% | +21,73% | 9,35% | 0,55 |
| 365d | 20 | +1,44% | +21,73% | 9,35% | 0,55 |
| 730d | off | +0,66% | +16,39% | 12,40% | 0,39 |
| 730d | 12 | +4,47% | +20,20% | 12,40% | 0,54 |
| 730d | 15 | +7,09% | +22,82% | 10,90% | 0,65 |
| 730d | 20 | **+8,92%** | **+24,65%** | 10,95% | **0,73** |
| 1095d | off | −15,82% | −5,20% | 15,97% | −0,32 |
| 1095d | 12 | −16,44% | −5,82% | 16,66% | −0,37 |
| 1095d | 15 | −12,80% | −2,18% | 14,50% | −0,23 |
| 1095d | 20 | −2,06% | +8,56% | 11,22% | 0,26 |

Reproduksi: `bin/rails 'momentum:buffer_sweep[extended]'`

### Cara membaca tabel ini

**Return absolutnya lemah; alpha-nya yang menarik.** Di jendela 365 dan 730 hari, return absolut berkisar −4% sampai +9% — tidak mengesankan. Tapi alpha terhadap IHSG **+16% sampai +25%**, karena IHSG turun lebih dalam pada periode yang sama. Artinya kontribusi utamanya adalah **menghindari kerugian**, bukan mengejar keuntungan — konsisten dengan gate regime yang menahan portofolio ke cash saat pasar risk-off.

**Jendela 1095 hari rugi di hampir semua konfigurasi.** Ini jendela terpanjang dan paling dekat dengan batas ketersediaan data (lihat batasan), jadi paling sedikit bisa diandalkan — tapi tetap dicantumkan karena menghilangkannya berarti memilih jendela yang menguntungkan.

**Buffer zone konsisten membantu, dan sensitivitasnya mencurigakan.** Di ketiga jendela, buffer memperbaiki return dan Sharpe sekaligus menurunkan drawdown. Tapi di jendela 1095d, selisih buffer 15 → 20 mengubah return dari −12,80% ke −2,06% — 10,7 poin persentase hanya dari menggeser satu parameter. Sensitivitas sebesar itu adalah tanda **overfitting**, bukan tanda penemuan. Buffer 20 memberi angka terbaik di dua dari tiga jendela, dan justru karena itu ia patut dicurigai, bukan dipilih.

## Forward tracking (paper, uang tidak sungguhan)

```
Forward tracking: 2026-07-16 → 2026-08-24 (21 hari-snapshot)
Equity paper: 100.00 (+0.00%)  maxDD: -0.00%  |  IHSG: 4.42%
Alpha vs IHSG: -4.42%  |  Regime hari ini: risk_off
Holdings: CASH
```

Reproduksi: `bin/rails momentum:paper`

**Ini hasil yang tidak menyenangkan, dan justru yang paling informatif.** Sejak inception, gate regime menahan portofolio **100% di cash selama seluruh 21 hari-snapshot**, sementara IHSG naik 4,42%. Jadi alpha forward-nya **−4,42%**.

Backtest bilang gate regime menyelamatkan dari penurunan. Forward tracking bilang gate yang sama membuat ketinggalan kenaikan. Keduanya konsisten dengan satu penjelasan: gate ini **mengurangi eksposur, bukan meningkatkan seleksi** — dan apakah itu bagus sepenuhnya tergantung arah pasar berikutnya, yang tidak diketahui.

21 hari-snapshot terlalu pendek untuk menyimpulkan apa pun. Gate promosi strategi ini butuh 8 minggu; sampai itu tercapai, strategi tetap dalam observasi dan alert-nya di-mute.

## Batasan — baca bagian ini

### Reproducibility: run pertama memberi angka yang salah

Backtest mengambil histori candle yang kurang secara **on-demand**, tanpa peringatan. Run pertama pada 2026-08-26 memberi **−6,78%** untuk 365d/buffer-15. Run berikutnya, dengan parameter identik, memberi **+1,44%** — dan stabil di angka itu pada dua run berikutnya lagi.

Penyebabnya cache candle yang tumbuh selama proses:

| | Run pertama | Setelah cache hangat |
|---|---|---|
| Candle saham | 517.066 | 705.717 (+36%) |
| Candle indeks | 701 | 1.199 (+71%) |

**Selisih 8,2 poin persentase, tanpa satu pun peringatan.** Guard `check_coverage!` dengan `MAX_MISSING_SHARE = 0.10` tidak menyala, artinya coverage saat itu masih di atas 90% — tapi 10% data hilang ternyata cukup untuk menggeser hasil sebesar itu. **Toleransi 10% itu terlalu longgar** dan seharusnya diperketat.

Semua angka di dokumen ini diambil dari cache hangat dan diverifikasi reproducible.

### Batasan lain

- **Sampel pendek.** Data indeks hanya ≈1.199 candle harian (≈4,8 tahun bursa) dan jendela 1095 hari sudah menyentuh batas itu. Belum melewati satu siklus pasar penuh.
- **Survivorship bias.** Universe dibentuk dari saham yang masih listing hari ini, jadi emiten yang sudah delisting tidak ikut terhitung. Ini membuat hasil backtest **lebih baik** dari kenyataan.
- **Gate regime di-bypass saat backtest.** Rake task `backtest:run` menyatakannya sendiri di outputnya. Jadi angka backtest dan perilaku forward tracking tidak sepenuhnya mengukur hal yang sama.
- **Fee dan slippage adalah estimasi**, bukan hasil fill sebenarnya. Tidak ada model market impact.
- **Tidak ada koreksi multiple-testing.** Tabel di atas memuat 12 kombinasi. Memilih yang terbaik dari 12 percobaan lalu melaporkannya sebagai temuan adalah kekeliruan statistik; itu sebabnya bagian di atas menyoroti sensitivitas parameter alih-alih menonjolkan angka terbaik.
- **Belum pernah dieksekusi dengan uang sungguhan.**

## Paper trading per strategi — di sini letak masalahnya

Diambil dari tabel `paper_trades`, seluruh trade yang sudah ditutup: **16.879 trade, 2026-05-26 → 2026-08-26** (3 bulan).

### Agregat

| Metrik | Nilai |
|---|---|
| Trade closed | 16.879 |
| Win / loss | 1.309 / 15.570 |
| Win rate | **7,76%** |
| Avg P&L per trade | **−0,196%** |
| Profit factor | **0,784** (gain 12.026,9 / loss 15.335,9) |

Profit factor di bawah 1 berarti total kerugian melebihi total keuntungan. Ini bukan hasil yang bagus, dan tidak ada gunanya dibungkus.

### Per strategi

| Strategi | n | Win rate | Avg P&L | Sum P&L |
|---|---|---|---|---|
| `CONFLUENCE_BEARISH` | 13.481 | 0,6% | +0,00% | +25,8 |
| `CONFLUENCE_BULLISH` | 2.956 | 35,4% | −1,00% | **−2.957,5** |
| `SWING_PICK` | 270 | 40,0% | −0,38% | −102,4 |
| `MACD_BULLISH` | 38 | 28,9% | −3,99% | −151,6 |
| `MACD_BEARISH` | 33 | 54,5% | −2,52% | −83,1 |
| `SQUEEZE_BREAKOUT` | 27 | 18,5% | −1,03% | −27,8 |
| `BB_BREAKOUT_UPPER` | 26 | 88,5% | +1,28% | +33,3 |
| `RSI_OVERSOLD` | 16 | 18,8% | −2,86% | −45,7 |
| `VOLUME_SPIKE` | 8 | 50,0% | −0,13% | −1,0 |
| `RSI_OVERBOUGHT` | 8 | 50,0% | +0,27% | +2,2 |
| `BB_BREAKOUT_LOWER` | 7 | 0,0% | −1,24% | −8,7 |
| `RSI_FAST_OVERSOLD` | 4 | 50,0% | +0,52% | +2,1 |
| `RSI_FAST_OVERBOUGHT` | 4 | 0,0% | −1,38% | −5,5 |
| `MACD_BULL_CROSS` | 1 | 100,0% | +11,02% | +11,0 |

### Tiga temuan dari tabel ini

**1. Satu strategi menyumbang hampir seluruh kerugian.** `CONFLUENCE_BULLISH` menghasilkan −2.957,5 dari total −3.309 — sekitar **89% dari seluruh kerugian berasal dari satu strategi**. Menonaktifkannya, bukan menyetel yang lain, adalah tindakan dengan dampak terbesar.

**2. `CONFLUENCE_BEARISH` adalah pembangkit sinyal degenerat, bukan strategi.** n = 13.481 — **80% dari seluruh trade** — dengan win rate **0,6%** dan avg P&L +0,00%. Sesuatu yang menghasilkan tiga belas ribu sinyal dan hampir tidak pernah menang bukan strategi yang berkinerja buruk; ia rusak. Volumenya juga membuat statistik agregat tidak bermakna: win rate keseluruhan 7,76% hampir seluruhnya cerminan strategi ini.

**3. Strategi dengan angka terbaik justru yang sampelnya terkecil.** `BB_BREAKOUT_UPPER` (WR 88,5%, avg +1,28%) hanya n=26. `MACD_BULL_CROSS` menunjukkan +11,02% dari **satu** trade. Angka-angka itu tidak berarti apa pun, dan mencantumkannya sebagai keberhasilan akan menyesatkan.

## Strategi yang gagal

- **`SQUEEZE_BREAKOUT`** — win rate 18,5%, avg −1,03% dari 27 trade. Membenarkan keputusan membatasinya hanya untuk crypto dan tidak memakainya untuk saham.
- **`CONFLUENCE_BULLISH`** — sumber 89% kerugian (di atas). `SignalConfluenceService` memang masih paper baseline dengan alert **di-mute**; data ini menjelaskan kenapa itu keputusan yang tepat.
- **`CONFLUENCE_BEARISH`** — rusak, bukan sekadar merugi (di atas).
- **`RSI_OVERSOLD`** — win rate 18,8%, avg −2,86%. Sampel kecil (n=16) tapi arahnya konsisten dengan `RSI_FAST_OVERSOLD`.

## Bug yang ditemukan saat menyusun dokumen ini

**Max drawdown pada dashboard salah hitung.** Dashboard menampilkan `Max Drawdown -4152.12%`. Drawdown ekuitas secara matematis tidak mungkin melewati −100%. Angka itu berasal dari **penjumlahan `pnl_pct` per trade** (sum = −3.309, dan tumbuh seiring trade baru ditutup), bukan dari peak-to-trough kurva ekuitas yang di-compound. Belum diperbaiki; dicatat di sini supaya angka di dashboard tidak dipercaya sebagai drawdown.

## Kesimpulan yang jujur

Sistem ini berhasil melakukan apa yang seharusnya dilakukan sistem pengukuran: **memberi tahu bahwa strateginya belum terbukti bekerja, dan menunjukkan di mana persoalannya.**

Yang bisa dikatakan dengan data ini: strategi cross-sectional momentum dengan gate regime mengurangi drawdown dan mengalahkan IHSG secara relatif di jendela 1–2 tahun, terutama dengan **menghindari eksposur** saat risk-off — bukan dengan memilih saham lebih baik.

Yang **tidak** bisa dikatakan: bahwa sistem ini menghasilkan uang. Bukti yang bertentangan lebih banyak daripada yang mendukung:

- Return absolut backtest tipis (−4% s/d +9%), dan jendela terpanjang rugi
- Sensitivitas parameter mengkhawatirkan (buffer 15 → 20 menggeser 10,7 poin persentase)
- Forward tracking nol selama 21 hari sementara IHSG naik
- Paper trading profit factor **0,784** — kerugian melebihi keuntungan
- Satu strategi (`CONFLUENCE_BULLISH`) menyumbang 89% kerugian
- Satu lagi (`CONFLUENCE_BEARISH`) rusak dan mendominasi 80% volume trade
- Run pertama backtest memberi angka yang salah tanpa peringatan

Tindakan berikutnya yang jelas dari data ini, berurutan: **matikan `CONFLUENCE_BULLISH`**, **perbaiki atau hapus `CONFLUENCE_BEARISH`**, **perketat `MAX_MISSING_SHARE`**, dan **perbaiki perhitungan max drawdown**. Baru setelah itu angka agregatnya layak dibaca lagi.

Strategi tetap dalam observasi. Tidak ada uang sungguhan yang pernah dipertaruhkan di sini, dan berdasarkan data di atas, itu keputusan yang benar.

---

# Pembaruan 2026-09-16 — pembersihan strategi, perbaikan metrik, uji smart money

## 1. Strategi yang dihapus

Berdasarkan angka di dokumen ini, empat jalur sinyal dihapus dari kode (bukan
di-mute — dihapus):

| Dihapus | Alasan |
|---|---|
| `SignalConfluenceService` | sumber 89% kerugian paper; rugi out-of-sample |
| `SqueezeBreakoutService` | WR 18,5%, avg −1,03% |
| `IdxScannerService` (SWING_PICK) | n=270, WR 40%, avg −0,38% |
| `BacktestService` (per-trade) | tak ada lagi strategi per-trade untuk diuji |

Ikut terhapus: `SignalEvaluatorJob`, `SetupLabeler`, `lib/tasks/backtest.rake`,
dan test terkait. `IdxScannerJob` DIPERTAHANKAN tapi disusutkan menjadi pengambil
candle 1d — momentum bergantung padanya (StockPollerJob hanya jalan saat bursa buka).

Jalur sinyal yang tersisa: **momentum + gate regime IHSG**. Tidak ada yang lain.

## 2. Max drawdown — salah dua kali sebelum benar

Dashboard menampilkan `Max Drawdown -4152,12%`. Perbaikannya butuh dua iterasi,
dan iterasi pertama layak dicatat karena terlihat benar padahal tidak:

| Versi | Rumus | Hasil (saham) | Masalah |
|---|---|---|---|
| v1 (lama) | `cum += pnl_pct` | **−4152,12%** | penjumlahan aritmetik, tak berbatas |
| v2 | equity berurutan per trade | **−100,00%** | 13.041 trade di-compound seolah antre |
| v3 (sekarang) | kurva ekuitas **harian** | **−7,52%** | — |

v2 gagal karena datanya punya **13.041 trade tutup dalam 61 hari bursa (~214 per
hari)** — posisinya paralel, bukan antre. Meng-compound avg −0,28%/trade sebanyak
13.041 kali memberi equity ≈ 0, jadi drawdown selalu mentok 100%: rumus benar,
pertanyaan salah. v3 merata-ratakan trade yang tutup di hari yang sama (proxy
portofolio equal-weight) lalu meng-compound antar hari.

Angka setelah perbaikan: **saham −7,52%**, **crypto −11,06%**.

Test juga menemukan bug nyata sepanjang jalan: trade closed bisa punya `pnl_pct`
tapi `exit_at` nil, yang membuat pengelompokan harian meledak. Baris seperti itu
kini dibuang dari kurva (bukan dipaksa ke satu bucket palsu).

## 3. MAX_MISSING_SHARE 0,10 → 0,02

Guard cakupan data diperketat, dan **langsung menemukan sesuatu**: pada universe
EXTENDED, 9 dari 223 simbol (4,0%) tidak punya histori candle sama sekali —
WSKT, SCBD, RMBA, MFIN, COWL, GAMA, LCGP, ENVY, SKYB, semuanya saham
suspend/delisting. Ambang 10% lama meloloskan ini tanpa suara.

Simbol-simbol itu dikeluarkan dari universe uji **secara sadar dan dilaporkan**,
bukan dengan melonggarkan kembali ambangnya.

## 4. Aliran dana asing (smart money) — pipeline jadi, hipotesis GAGAL

### Data berhasil ditarik

Tabel `foreign_flows` (terpisah penuh dari `Candle`, sengaja: satu sumber rusak
tak boleh menjatuhkan keduanya).

```
312.589 baris · 979 simbol · 326 hari bursa · 2025-05-05 .. 2026-09-15
```

Sumber: endpoint `TradingSummary/GetStockSummary` milik IDX.

**Catatan akses:** `curl` mendapat HTTP 403 Cloudflare dari SEMUA endpoint
idx.co.id, dengan header browser selengkap apa pun. `Net::HTTP` Ruby tembus tanpa
masalah — Cloudflare memfilter fingerprint TLS, bukan header. Jadi jangan
menyimpulkan "IDX memblokir kita" dari hasil `curl`. Tersedia juga jalur berkas
(`idx:foreign_flow_ingest`) kalau suatu saat akses jaringan tertutup.

### Bug satuan yang nyaris lolos

`ForeignBuy` / `ForeignSell` IDX bersatuan **LEMBAR SAHAM**, bukan rupiah.
Contoh (BBCA, 2026-09-15): `ForeignBuy` 65.949.600 sementara `Value` hari itu
Rp 614.491.297.500 dan `Volume` 95.608.200 lembar.

Versi pertama membagi lembar dengan rupiah. Hasilnya rasio ~0,000 untuk **semua**
saham — angka yang kelihatan "kecil tapi masuk akal" dan hampir diterima sebagai
sinyal lemah. Ketahuan hanya karena dicek manual terhadap BBCA. Metrik kini
lembar-dibagi-lembar: `Σ net lembar asing / Σ volume`, tanpa asumsi harga.
Ada regression test yang memakukan angka BBCA itu.

### Hasil uji hipotesis

Universe 214 simbol (EXTENDED, sudah disaring cakupan candle & flow), 365 hari,
rebalance bulanan, fee 0,4%:

| Varian | Return | Alpha vs IHSG | Max DD | Sharpe |
|---|---|---|---|---|
| momentum polos | −3,98% | +16,31% | 11,85% | −0,03 |
| flow ≥ 0 (asing net beli) | +4,31% | +24,60% | 8,00% | 0,84 |
| flow ≥ 0,02 | +5,81% | +26,10% | 4,39% | 1,27 |
| flow ≥ 0,05 | +11,01% | +31,30% | 2,64% | 2,14 |

Baris pertama **persis mereproduksi** angka 365d/buffer-off di tabel walk-forward
di atas (−3,98% / +16,31% / 11,85% / −0,03) — konfirmasi bahwa baseline-nya sama.

Monoton membaik di keempat ambang. Terlihat meyakinkan. Ternyata tidak.

### Tiga kontrol yang membatalkannya

**a. Plasebo terbalik — sebagian lolos, sebagian tidak**

| Varian | Return | Alpha |
|---|---|---|
| asing NET JUAL (flow ≤ 0) | **−12,16%** | +8,13% |
| asing jual kuat (flow ≤ −0,05) | **+3,82%** | +24,11% |

Arah dasarnya benar (net jual lebih buruk dari polos). Tapi "jual kuat" justru
**mengalahkan** momentum polos — padahal hipotesisnya memprediksi sebaliknya.

**b. Konsentrasi — bukan penyebabnya**

Filter paling ketat masih meloloskan 22–40 nama per tanggal rebalance, jauh di
atas top-10 yang dibeli. Jadi hasilnya bukan artefak portofolio yang menciut.

**c. Uji permutasi — ini yang menentukan**

25 subset **acak** berukuran sama (~105 dari 214 simbol), tanpa informasi aliran
dana sama sekali:

```
acak:    median -2,77%   rata2 -1,28%
         p10 -10,55%     p90 +10,72%
         min -15,55%     maks +17,74%
flow>=0: +4,31%

subset acak yang mengalahkan filter flow: 8 dari 25
p-value empiris: ~0,32
```

**+4,31% jatuh di dalam sebaran acak, bahkan tidak di kuartil teratas.** Sepertiga
subset acak melakukannya lebih baik tanpa tahu apa pun tentang asing.

### Kesimpulan

Hipotesis **tidak terkonfirmasi**. Yang sebenarnya ditunjukkan tabel pertama
bukan "aliran dana asing punya edge", melainkan **satu jendela 365 hari tidak
mampu membedakan sinyal dari keberuntungan** — sebaran acaknya selebar 33 poin
persentase (−15,55% s/d +17,74%). Setiap filter apa pun akan menghasilkan angka
di dalam rentang itu, dan monotonisitas antar-ambang tidak menyelamatkannya
karena keempat ambang menguji jendela yang sama.

Ini pelajaran yang sama dengan sensitivitas buffer 15→20 di bagian atas dokumen,
hanya dengan alat ukur yang lebih tajam.

**Overlay smart money tetap MATI secara default** (`min_flow_ratio: nil`).
Kodenya ada, teruji, dan datanya mengalir harian — tapi ia tidak akan menyentuh
keputusan apa pun sampai ada bukti yang lolos kontrol acak.

### Apa yang dibutuhkan untuk menguji ulang dengan benar

1. **Riwayat lebih panjang.** 326 hari bursa hanya cukup untuk satu jendela.
   Ingest harian sudah dijadwalkan (`idx:foreign_flow_daily`, 16:45 WIB); dalam
   ~1 tahun lagi ada cukup data untuk walk-forward yang sesungguhnya.
2. **Beberapa jendela terpisah**, bukan satu jendela dengan empat ambang.
3. **Uji permutasi sebagai syarat lulus**, bukan sebagai pemeriksaan tambahan —
   aturannya: p < 0,05 terhadap subset acak berukuran sama, atau hipotesis ditolak.

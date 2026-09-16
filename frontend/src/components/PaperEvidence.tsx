import type { PaperStatsData, PaperTrade } from "../types";
import { dec, dirClass, idr, signedPct, timeAgo } from "../lib/format";

interface Props {
  data: PaperStatsData | null;
  openTrades: PaperTrade[] | null;
}

// Strategi yang sudah dihapus dari kode. Angkanya beku dan tidak akan bertambah.
const RETIRED = ["CONFLUENCE", "SQUEEZE", "SWING_PICK", "MACD", "RSI", "BB_", "VOLUME"];
const isRetired = (s: string) => RETIRED.some((r) => s.startsWith(r));

export function PaperEvidence({ data, openTrades }: Props) {
  if (!data) {
    return (
      <div className="empty">
        <div className="empty-title">Statistik paper tak terbaca.</div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          Tabel <span className="ink-2">paper_trade_stats_summaries</span> kosong atau tak
          terjangkau dengan kunci anon.
        </p>
      </div>
    );
  }

  const pf = data.profit_factor;

  // Drawdown ekuitas tak mungkin melewati 100%. Kalau angkanya lewat, ringkasan
  // ini di-materialize oleh versi lama RiskMetrics yang menjumlahkan pnl_pct
  // secara aritmetik (dashboard sempat menampilkan -4152,12%). Tampilkan apa
  // adanya TAPI tandai sebagai rusak — menyembunyikannya membuat angka salah
  // terbaca sebagai benar, dan itu persis yang kita coba hentikan.
  const ddBroken = data.max_drawdown !== null && data.max_drawdown > 100;

  return (
    <>
      <div className="rail">
        <div className="rail-cell">
          <div className="reading-label">Profit factor</div>
          <div className={`reading-value ${pf === null ? "ink-3" : pf >= 1 ? "rise" : "fall"}`}>
            {dec(pf)}
          </div>
          <div className="reading-note">
            {pf !== null && pf < 1 ? "kerugian melebihi keuntungan" : "gain ÷ loss"}
          </div>
        </div>

        <div className="rail-cell">
          <div className="reading-label">Win rate</div>
          <div className="reading-value">{dec(data.win_rate, 1)}%</div>
          <div className="reading-note">
            <span className="rise">{idr(data.winners)} menang</span> ·{" "}
            <span className="fall">{idr(data.losers)} kalah</span>
          </div>
        </div>

        <div className="rail-cell">
          <div className="reading-label">Rata-rata per trade</div>
          <div className={`reading-value ${dirClass(data.avg_pnl)}`}>
            {signedPct(data.avg_pnl)}
          </div>
          <div className="reading-note">ekspektansi</div>
        </div>

        <div className="rail-cell">
          <div className="reading-label">Max drawdown</div>
          <div className={`reading-value ${ddBroken ? "ink-3" : ""}`}>
            {data.max_drawdown === null ? "—" : `−${dec(data.max_drawdown)}%`}
          </div>
          {ddBroken ? (
            <div className="reading-note evidence evidence-failed">
              ○ mustahil &gt;100% — ringkasan belum di-materialize ulang
            </div>
          ) : (
            <div className="reading-note evidence evidence-proven">
              ● kurva harian, bukan jumlah pnl
            </div>
          )}
        </div>

        <div className="rail-cell">
          <div className="reading-label">Sharpe</div>
          <div className={`reading-value ${data.sharpe === null ? "ink-3" : dirClass(data.sharpe)}`}>
            {dec(data.sharpe)}
          </div>
          <div className="reading-note">per trade, tanpa anualisasi</div>
        </div>
      </div>

      {data.by_strategy.length > 0 && (
        <>
          <div className="scroll-x" style={{ marginTop: 24 }}>
            <table className="itable">
              <caption className="sr-only">
                Hasil paper trading per strategi, termasuk yang sudah dipensiunkan
              </caption>
              <thead>
                <tr>
                  <th scope="col">Strategi</th>
                  <th scope="col" className="num">n</th>
                  <th scope="col" className="num">Win rate</th>
                  <th scope="col" className="num">Rata-rata</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {data.by_strategy.map((s) => {
                  const gone = isRetired(s.strategy);
                  return (
                    <tr key={s.strategy}>
                      <td className={gone ? "ink-3" : "sym"}>{s.strategy}</td>
                      <td className={`num ${gone ? "ink-3" : ""}`}>{idr(s.total)}</td>
                      <td className={`num ${gone ? "ink-3" : ""}`}>{dec(s.win_rate, 1)}%</td>
                      <td className={`num ${gone ? "ink-3" : dirClass(s.avg_pnl)}`}>
                        {signedPct(s.avg_pnl)}
                      </td>
                      <td className={`evidence ${gone ? "evidence-failed" : "evidence-watch"}`}>
                        {gone ? "○ dihapus dari kode" : "◐ observasi"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <p className="t-xs ink-3 measure" style={{ marginTop: 12 }}>
            Baris bertanda <span className="evidence evidence-failed">○</span> adalah strategi
            yang sudah dihapus dari kode. Angkanya beku dan tidak akan bertambah —
            dipertahankan di sini karena alasan penghapusannya adalah bukti, dan bukti yang
            disembunyikan cenderung diulang.
          </p>
        </>
      )}

      {openTrades && openTrades.length > 0 && (
        <div className="scroll-x" style={{ marginTop: 24 }}>
          <table className="itable">
            <caption className="sr-only">Posisi paper yang masih terbuka</caption>
            <thead>
              <tr>
                <th scope="col">Terbuka</th>
                <th scope="col">Strategi</th>
                <th scope="col" className="num">Entry</th>
                <th scope="col" className="num">Sekarang</th>
                <th scope="col" className="num">P&amp;L</th>
                <th scope="col" className="num">Sejak</th>
              </tr>
            </thead>
            <tbody>
              {openTrades.map((t) => (
                <tr key={t.id}>
                  <td className="sym">{t.symbol.replace(".JK", "")}</td>
                  <td className="ink-3">{t.strategy}</td>
                  <td className="num">{idr(t.entry_price)}</td>
                  <td className="num">{t.current_price === null ? "—" : idr(t.current_price)}</td>
                  <td className={`num ${dirClass(t.current_pnl_pct)}`}>
                    {signedPct(t.current_pnl_pct)}
                  </td>
                  <td className="num ink-3">{timeAgo(t.entry_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

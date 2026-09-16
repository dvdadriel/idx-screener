import type { Signal } from "../types";
import { jakartaTime } from "../lib/format";

const RETIRED = ["CONFLUENCE", "SQUEEZE", "SWING_PICK", "MACD", "RSI", "BB_", "VOLUME"];
const isRetired = (s: string) => RETIRED.some((r) => s.startsWith(r));

export function SignalsTable({ signals }: { signals: Signal[] | null }) {
  if (signals === null) {
    return (
      <div className="empty">
        <div className="empty-title">Sinyal tak terbaca.</div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          Tabel <span className="ink-2">signals</span> tak terjangkau dengan kunci anon.
        </p>
      </div>
    );
  }

  if (signals.length === 0) {
    return (
      <div className="empty">
        <div className="empty-title">Tidak ada sinyal.</div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          Diam adalah keadaan normal. Strategi per-trade sudah dihapus; yang tersisa adalah
          peringkat momentum harian, dan itu terbit sebagai snapshot — bukan sebagai sinyal
          yang menyala sepanjang hari.
        </p>
      </div>
    );
  }

  return (
    <div className="scroll-x" style={{ marginTop: 12 }}>
      <table className="itable">
        <caption className="sr-only">Sinyal trading terbaru</caption>
        <thead>
          <tr>
            <th scope="col">Saham</th>
            <th scope="col">Strategi</th>
            <th scope="col">Arah</th>
            <th scope="col" className="num">Skor</th>
            <th scope="col" className="num">Waktu</th>
          </tr>
        </thead>
        <tbody>
          {signals.map((s) => {
            const buy = s.signal_type === "BUY";
            const gone = isRetired(s.strategy);
            return (
              <tr key={s.id}>
                <td className="sym">{s.symbol.replace(".JK", "")}</td>
                <td className={gone ? "ink-3" : ""}>
                  {s.strategy}
                  {gone && <span className="evidence evidence-failed"> ○</span>}
                </td>
                {/* Arah dibawa glyph DAN kata, bukan warna saja: defisiensi
                    merah-hijau paling umum dan di data finansial paling merugikan. */}
                <td className={buy ? "rise" : "fall"}>
                  <span aria-hidden="true">{buy ? "▲" : "▼"}</span> {s.signal_type}
                </td>
                <td className="num">{s.score === null ? "—" : Math.round(s.score * 100)}</td>
                <td className="num ink-3">{jakartaTime(s.fired_at)}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

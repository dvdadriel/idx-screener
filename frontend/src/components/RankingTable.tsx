import type { MomentumSnapshot } from "../types";
import { dirClass, idr, signedPct } from "../lib/format";

interface Props {
  picks: MomentumSnapshot[] | null;
  snapshotDate: string | null;
  riskOff: boolean;
}

/**
 * Keluaran inti produk. Tabel, bukan grid kartu: pembaca membandingkan ke bawah
 * satu kolom, dan angka rata kanan membuat titik desimalnya membentuk garis
 * tegak yang bisa dipindai mata.
 *
 * Menggantikan panel "Today's Swing Picks" yang query-nya ke strategi SWING_PICK —
 * strategi itu sudah dihapus dari kode, jadi panelnya mati diam-diam.
 */
export function RankingTable({ picks, snapshotDate, riskOff }: Props) {
  if (picks === null) {
    return (
      <div className="empty">
        <div className="empty-title">Peringkat tak terbaca.</div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          Tabel <span className="ink-2">momentum_snapshots</span> tak terjangkau dengan kunci
          anon. Pastikan migrasi <span className="ink-2">ExposeMomentumSnapshotsToAnon</span>
          sudah dijalankan di database produksi.
        </p>
      </div>
    );
  }

  if (picks.length === 0) {
    return (
      <div className="empty">
        <div className="empty-title">
          {snapshotDate
            ? "Cash — tidak ada peringkat yang direkam hari ini."
            : "Belum ada snapshot sama sekali."}
        </div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          {snapshotDate ? (
            <>
              Snapshot <span className="ink-2">{snapshotDate}</span> tercatat sebagai hari
              risk-off: gate IHSG menahan entry, jadi tak ada top-10 yang dibeli maupun
              dipantau. Peringkat kembali muncul begitu regime berbalik risk-on.
            </>
          ) : (
            <>
              Rantai harian <span className="ink-2">idx:daily_close</span> merekam peringkat
              setiap hari bursa. Baris pertama muncul setelah rantai itu berjalan sekali.
            </>
          )}
        </p>
      </div>
    );
  }

  const eligible = picks[0]?.eligible_count ?? null;

  return (
    <>
      {riskOff && (
        <p className="note">
          <span className="fall">Watchlist.</span> Sistem tidak membeli saat regime risk-off —
          daftar ini untuk dipantau, bukan sinyal beli.
        </p>
      )}

      <div className="scroll-x" style={{ marginTop: 12 }}>
        <table className="itable">
          <caption className="sr-only">Peringkat momentum harian dengan skor persentil</caption>
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Saham</th>
              <th scope="col" className="num">Skor</th>
              <th scope="col" className="num">Momentum</th>
              <th scope="col" className="num">Harga</th>
              <th scope="col">Status bukti</th>
            </tr>
          </thead>
          <tbody>
            {picks.map((p) => {
              const mom = p.momentum === null ? null : p.momentum * 100;
              return (
                <tr key={p.id}>
                  <td className={`rank ${p.rank === 1 ? "rank-lead" : ""}`}>
                    {String(p.rank ?? 0).padStart(2, "0")}
                  </td>
                  <td className="sym">{p.symbol?.replace(".JK", "")}</td>
                  <td className="num">{p.score ?? "—"}</td>
                  <td className={`num ${dirClass(mom)}`}>{signedPct(mom, 1)}</td>
                  <td className="num">Rp {p.price === null ? "—" : idr(p.price)}</td>
                  <td className="evidence evidence-watch">◐ observasi</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <p className="t-xs ink-3 measure" style={{ marginTop: 12 }}>
        Skor {eligible ? `adalah persentil di antara ${eligible} kandidat layak dan ` : ""}
        menyatakan peringkat relatif hari ini, bukan prediksi harga. Momentum dihitung dari
        return 6 bulan dengan 1 bulan terakhir dilewati, karena jangka pendek cenderung
        berbalik arah.
      </p>
    </>
  );
}

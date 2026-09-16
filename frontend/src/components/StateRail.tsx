import type { MomentumSummaryData } from "../types";
import { dec, dirClass, signedPct } from "../lib/format";

/**
 * Lima pembacaan dari satu keadaan instrumen, dipisah hairline dan bukan dibungkus
 * kartu: mereka sisi dari satu pengukuran, bukan lima objek terpisah.
 *
 * Tiap pembacaan membawa status buktinya sendiri. Baris "Aliran asing" sengaja
 * berdiri sejajar dengan yang lain meski jawabannya "tak dipakai" — overlay itu
 * gagal uji permutasi, dan kegagalan yang disembunyikan cenderung diulang.
 */
export function StateRail({ data }: { data: MomentumSummaryData | null }) {
  if (!data) {
    return (
      <div className="empty">
        <div className="empty-title">Ringkasan momentum tak terbaca.</div>
        <p className="t-xs ink-3" style={{ marginTop: 8 }}>
          Tabel <span className="ink-2">momentum_tracker_summaries</span> kosong atau tak
          terjangkau. Ia diisi oleh <span className="ink-2">idx:daily_close</span> setiap hari
          bursa; kalau pesan ini bertahan lewat satu hari bursa, rantai hariannya yang bermasalah.
        </p>
      </div>
    );
  }

  const alpha =
    data.ihsg_return === null ? null : Number((data.total_return - data.ihsg_return).toFixed(2));

  return (
    <div className="rail">
      <div className="rail-cell">
        <div className="reading-label">Posisi</div>
        <div className="reading-value">
          {data.holdings.length > 0 ? `${data.holdings.length} nama` : "CASH"}
        </div>
        <div className="reading-note">
          {data.holdings.length > 0 ? "equal-weight" : "gate regime menahan entry"}
        </div>
      </div>

      <div className="rail-cell">
        <div className="reading-label">Return paper</div>
        <div className={`reading-value ${dirClass(data.total_return)}`}>
          {signedPct(data.total_return)}
        </div>
        <div className="reading-note evidence evidence-watch">◐ observasi · uang tidak nyata</div>
      </div>

      <div className="rail-cell">
        <div className="reading-label">Alpha vs IHSG</div>
        <div className={`reading-value ${dirClass(alpha)}`}>{signedPct(alpha)}</div>
        <div className="reading-note">IHSG {signedPct(data.ihsg_return)}</div>
      </div>

      <div className="rail-cell">
        <div className="reading-label">Max drawdown</div>
        <div className="reading-value">
          {data.max_drawdown === 0 ? "0,00%" : `−${dec(data.max_drawdown)}%`}
        </div>
        <div className="reading-note evidence evidence-proven">● kurva ekuitas harian</div>
      </div>

      <div className="rail-cell">
        <div className="reading-label">Aliran asing</div>
        <div className="reading-value ink-3">tak dipakai</div>
        <div className="reading-note evidence evidence-failed">
          ○ gagal uji permutasi · p≈0,32
        </div>
      </div>
    </div>
  );
}

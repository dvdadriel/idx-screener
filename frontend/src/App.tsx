import { useEffect, useState } from "react";
import { supabase } from "./lib/supabase";
import { isIdxOpenNow } from "./lib/idxMarket";
import { SignalsTable } from "./components/SignalsTable";
import { StateRail } from "./components/StateRail";
import { RankingTable } from "./components/RankingTable";
import { PaperEvidence } from "./components/PaperEvidence";
import { idr } from "./lib/format";
import type {
  Signal,
  PaperTrade,
  LatestClose,
  MomentumSnapshot,
  MomentumSummaryData,
  PaperStatsData,
} from "./types";

interface DashboardState {
  signals: Signal[] | null;
  closes: LatestClose[] | null;
  snapshots: MomentumSnapshot[] | null;
  momentum: MomentumSummaryData | null;
  paperStats: PaperStatsData | null;
  openTrades: PaperTrade[] | null;
}

const EMPTY: DashboardState = {
  signals: null,
  closes: null,
  snapshots: null,
  momentum: null,
  paperStats: null,
  openTrades: null,
};

export function App() {
  const [state, setState] = useState<DashboardState>(EMPTY);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        // Peringkat diambil dua langkah: cari tanggal snapshot terakhir, lalu
        // ambil barisnya. Satu query "order by date desc limit 10" akan salah —
        // ia memotong lintas tanggal kalau hari terakhir punya kurang dari 10
        // baris (hari risk-off hanya punya satu baris marker).
        const latest = await supabase
          .from("momentum_snapshots")
          .select("snapshot_date")
          .order("snapshot_date", { ascending: false })
          .limit(1)
          .maybeSingle();

        const snapshotDate = latest.error ? null : (latest.data?.snapshot_date ?? null);

        const [signalsRes, closesRes, snapsRes, momentumRes, statsRes, tradesRes] =
          await Promise.all([
            supabase
              .from("signals")
              .select("*")
              .eq("asset_type", "stock")
              .order("fired_at", { ascending: false })
              .limit(50),
            supabase
              .from("latest_candle_closes")
              .select("*")
              .eq("asset_type", "stock")
              .eq("timeframe", "1d"),
            snapshotDate
              ? supabase
                  .from("momentum_snapshots")
                  .select("*")
                  .eq("snapshot_date", snapshotDate)
                  .order("rank", { ascending: true })
              : Promise.resolve({ data: [], error: null }),
            supabase.from("momentum_tracker_summaries").select("data").maybeSingle(),
            supabase
              .from("paper_trade_stats_summaries")
              .select("data")
              .eq("asset_type", "stock")
              .maybeSingle(),
            supabase
              .from("paper_trades")
              .select("*")
              .eq("asset_type", "stock")
              .eq("status", "open")
              .order("entry_at", { ascending: false })
              .limit(20),
          ]);

        setState({
          signals: signalsRes.error ? null : (signalsRes.data as Signal[]),
          closes: closesRes.error ? null : (closesRes.data as LatestClose[]),
          // Baris marker hari risk-off (symbol null) dibuang di sini: ia data
          // regime, bukan pick. Array kosong tetap beda dari null — "sistem
          // memilih cash" bukan "query gagal".
          snapshots: snapsRes.error
            ? null
            : ((snapsRes.data ?? []) as MomentumSnapshot[]).filter((r) => r.symbol !== null),
          momentum: momentumRes.error
            ? null
            : ((momentumRes.data?.data as MomentumSummaryData) ?? null),
          paperStats: statsRes.error
            ? null
            : ((statsRes.data?.data as PaperStatsData) ?? null),
          openTrades: tradesRes.error ? null : (tradesRes.data as PaperTrade[]),
        });
      } catch {
        setState(EMPTY);
      } finally {
        setLoading(false);
      }
    }

    load();
  }, []);

  const m = state.momentum;
  const riskOff = m?.regime_today !== "risk_on";
  const idxOpen = isIdxOpenNow();
  const covered = state.closes?.length ?? 0;

  return (
    <div className="page">
      {/* Gate regime menentukan boleh-tidaknya sistem memegang apa pun, jadi ia
          fakta pertama di halaman dan tetap terlihat saat pembaca menggulir. */}
      <header className="bar">
        <div className="shell bar-row">
          <span className="wordmark">IDXSCREENER</span>

          <div className="bar-regime">
            <span className="t-xs ink-3">regime</span>
            {loading ? (
              <span className="skeleton" style={{ width: 84 }} />
            ) : (
              <span className={`chip ${riskOff ? "fall" : "rise"}`}>
                <span aria-hidden="true">{riskOff ? "■" : "▲"}</span>
                {riskOff ? "RISK-OFF" : "RISK-ON"}
              </span>
            )}
            <span className="t-xs ink-3 truncate">
              bursa {idxOpen ? "buka" : "tutup"}
            </span>
          </div>
        </div>
      </header>

      <main className="main">
        <div className="shell stack">
          <section aria-labelledby="state-h">
            <div className="band-head">
              <h2 id="state-h" className="band-title">Portfolio state</h2>
              <span className="band-meta">
                {m?.as_of
                  ? `${m.inception} → ${m.as_of} · ${m.tracked_days} hari-snapshot`
                  : "belum ada snapshot"}
              </span>
            </div>
            {loading ? <RailSkeleton /> : <StateRail data={m} />}
          </section>

          <section aria-labelledby="rank-h">
            <div className="band-head">
              <h2 id="rank-h" className="band-title">Peringkat momentum</h2>
              <span className="band-meta">6 bulan, lewati 1 bulan terakhir</span>
            </div>
            {loading ? (
              <TableSkeleton rows={6} />
            ) : (
              <RankingTable
                picks={state.snapshots}
                snapshotDate={m?.as_of ?? null}
                riskOff={riskOff}
              />
            )}
          </section>

          <section aria-labelledby="paper-h">
            <div className="band-head">
              <h2 id="paper-h" className="band-title">Bukti paper trading</h2>
              <span className="band-meta">
                {state.paperStats
                  ? `${idr(state.paperStats.total_closed)} trade tertutup · ${state.paperStats.open_count} terbuka`
                  : ""}
              </span>
            </div>
            {loading ? (
              <RailSkeleton />
            ) : (
              <PaperEvidence data={state.paperStats} openTrades={state.openTrades} />
            )}
          </section>

          <section aria-labelledby="sig-h">
            <div className="band-head">
              <h2 id="sig-h" className="band-title">Sinyal terkini</h2>
              <span className="band-meta">{state.signals?.length ?? 0} terakhir</span>
            </div>
            {loading ? <TableSkeleton rows={5} /> : <SignalsTable signals={state.signals} />}
          </section>

          <section aria-labelledby="cov-h">
            <div className="band-head">
              <h2 id="cov-h" className="band-title">Cakupan data</h2>
              <span className="band-meta">{idr(covered)} simbol punya candle 1d</span>
            </div>
            <div className="tokens" style={{ marginTop: 12 }}>
              {loading ? (
                <span className="skeleton" style={{ width: "100%" }} />
              ) : (
                (state.closes ?? []).slice(0, 60).map((c) => (
                  <span key={c.symbol}>
                    {c.symbol.replace(".JK", "")}{" "}
                    <span className="ink-3 nums">{idr(c.close)}</span>
                  </span>
                ))
              )}
            </div>
          </section>
        </div>
      </main>

      <footer className="foot">
        <div className="shell legend">
          <span>Paper trading — tidak pernah ada uang sungguhan di sini.</span>
          <span className="evidence evidence-proven">● tervalidasi</span>
          <span className="evidence evidence-watch">◐ observasi</span>
          <span className="evidence evidence-failed">○ gagal uji</span>
        </div>
      </footer>
    </div>
  );
}

/* Skeleton berbentuk seperti jawabannya, bukan spinner di tengah konten: tata
   letak tidak melompat saat data mendarat. */
function RailSkeleton() {
  return (
    <div className="rail">
      {Array.from({ length: 5 }, (_, i) => (
        <div className="rail-cell" key={i}>
          <span className="skeleton" style={{ display: "block", width: "60%" }} />
          <span
            className="skeleton"
            style={{ display: "block", width: "45%", height: "1.4lh", marginTop: 6 }}
          />
        </div>
      ))}
    </div>
  );
}

function TableSkeleton({ rows }: { rows: number }) {
  return (
    <div style={{ marginTop: 12 }}>
      {Array.from({ length: rows }, (_, i) => (
        <span
          key={i}
          className="skeleton"
          style={{ display: "block", marginTop: i === 0 ? 0 : 8, width: `${95 - i * 6}%` }}
        />
      ))}
    </div>
  );
}

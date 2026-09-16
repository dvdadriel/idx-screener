export interface Signal {
  id: number;
  asset_type: string;
  fired_at: string;
  metadata: Record<string, unknown>;
  score: number | null;
  signal_type: string | null;
  strategy: string;
  symbol: string;
}

export interface PaperTrade {
  id: number;
  asset_type: string;
  current_pnl_pct: number | null;
  current_price: number | null;
  entry_at: string;
  entry_price: number;
  exit_at: string | null;
  exit_price: number | null;
  pnl_pct: number | null;
  side: string;
  status: string;
  strategy: string;
  symbol: string;
}

/** Satu baris momentum_snapshots. Hari risk-off direkam sebagai marker tanpa
 *  simbol (symbol/rank null), jadi "tak ada pick" BUKAN berarti "tak ada
 *  snapshot" — membedakan keduanya adalah beda antara "sistem memilih cash" dan
 *  "pipeline mati". */
export interface MomentumSnapshot {
  id: number;
  snapshot_date: string;
  regime: string;
  rank: number | null;
  symbol: string | null;
  momentum: number | null;
  price: number | null;
  score: number | null;
  eligible_count: number | null;
}

export interface LatestClose {
  symbol: string;
  timeframe: string;
  asset_type: string;
  close: number;
  opened_at: string;
}

export interface MomentumSummaryData {
  inception: string | null;
  as_of: string | null;
  tracked_days: number;
  equity: number;
  total_return: number;
  max_drawdown: number;
  ihsg_return: number | null;
  regime_today: string | null;
  holdings: string[];
  equity_curve: [string, number][];
}

export interface TradeRef {
  symbol: string;
  strategy: string;
  pnl_pct: number;
  exit_at: string;
}

export interface StrategyBreakdown {
  strategy: string;
  total: number;
  wins: number;
  win_rate: number;
  avg_pnl: number;
}

export interface PaperStatsData {
  total_closed: number;
  open_count: number;
  winners: number;
  losers: number;
  win_rate: number;
  avg_pnl: number;
  avg_winner: number;
  avg_loser: number;
  best_trade: TradeRef | null;
  worst_trade: TradeRef | null;
  by_strategy: StrategyBreakdown[];
  expectancy: number;
  profit_factor: number | null;
  max_drawdown: number | null;
  sharpe: number | null;
}

class DashboardController < ApplicationController
  def index
    @crypto_enabled = CRYPTO_ENABLED

    @stock_signals  = TradingSignal.where(asset_type: "stock").order(fired_at: :desc).limit(50)
    @stock_candle_summary  = Candle.latest_closes(timeframe: "1d", asset_type: "stock").index_by(&:symbol)
    @stock_watchlist  = IdxMarket::WATCHLIST
    @idx_open         = IdxMarket.open_now?
    @idx_universe_size = (IdxUniverseService.all.size rescue IdxMarket::EXTENDED_WATCHLIST.size)

    if @crypto_enabled
      @crypto_signals = TradingSignal.where(asset_type: "crypto").order(fired_at: :desc).limit(50)
      @latest_sentiment = SentimentSnapshot.order(:captured_at).last
      @crypto_candle_summary = Candle.latest_closes(timeframe: "1h", asset_type: "crypto").index_by(&:symbol)
      @crypto_watchlist = MarketScannerService.watchlist
      @scanned_at       = MarketScannerService.scanned_at
    end

    # Momentum (strategi observasi): status forward-tracking + pick snapshot terakhir.
    @momentum = MomentumPaperTracker.new.call
    # SWING_PICK dihapus bersama IdxScannerService — tak ada lagi @swing_picks.
    @momentum_picks = @momentum[:as_of] ? MomentumSnapshot.for_date(@momentum[:as_of]).picks.order(:rank) : MomentumSnapshot.none

    @stock_stats  = PaperTradeStats.for("stock")
    @stock_open_trades  = PaperTrade.open_trades.where(asset_type: "stock").order(entry_at: :desc).limit(20)

    if @crypto_enabled
      @crypto_stats = PaperTradeStats.for("crypto")
      @crypto_open_trades = PaperTrade.open_trades.where(asset_type: "crypto").order(entry_at: :desc).limit(20)
    end
  end
end

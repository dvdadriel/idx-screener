require "test_helper"

class PaperTradeStatsTest < ActiveSupport::TestCase
  def make_trade(asset_type:, pnl:, status: "closed", strategy: "TEST")
    signal = TradingSignal.create!(
      symbol: "BTCUSDT", strategy: strategy, signal_type: "NEUTRAL",
      asset_type: asset_type, fired_at: Time.current
    )
    PaperTrade.create!(
      trading_signal: signal, symbol: "BTCUSDT", asset_type: asset_type,
      side: "BUY", strategy: strategy, entry_price: 100, entry_at: Time.current,
      status: status, pnl_pct: pnl
    )
  end

  test "computes win rate and averages over closed trades only" do
    make_trade(asset_type: "crypto", pnl: 10)
    make_trade(asset_type: "crypto", pnl: 4)
    make_trade(asset_type: "crypto", pnl: -6)
    make_trade(asset_type: "crypto", pnl: nil, status: "open") # ignored in closed stats

    stats = PaperTradeStats.for("crypto")

    assert_equal 3, stats[:total_closed]
    assert_equal 2, stats[:winners]
    assert_equal 1, stats[:losers]
    assert_in_delta 66.7, stats[:win_rate], 0.1
    assert_in_delta 2.67, stats[:avg_pnl], 0.01
    assert_equal 1, stats[:open_count]
  end

  test "isolates stats by asset type" do
    make_trade(asset_type: "crypto", pnl: 5)
    make_trade(asset_type: "stock",  pnl: -3)

    assert_equal 1, PaperTradeStats.for("crypto")[:total_closed]
    assert_equal 1, PaperTradeStats.for("stock")[:total_closed]
  end

  test "returns zeros with no trades" do
    stats = PaperTradeStats.for("crypto")
    assert_equal 0, stats[:total_closed]
    assert_equal 0, stats[:win_rate]
    assert_equal 0.0, stats[:avg_pnl]
  end

  def make_closed_with_exit(pnl:, exit_at:)
    t = make_trade(asset_type: "stock", pnl: pnl)
    t.update!(exit_at: exit_at)
    t
  end

  # Drawdown = kurva ekuitas HARIAN ber-compound (satu hari = satu periode), bukan
  # penjumlahan pnl_pct per trade. Tiga hari berbeda [+10, -6, +4]:
  #   equity 1.10 -> 1.034 -> 1.0754 ; puncak 1.10, lembah 1.034 -> DD 6.0%
  test "computes profit factor, max drawdown, sharpe over closed trades" do
    base = Time.current.beginning_of_day
    make_closed_with_exit(pnl: 10, exit_at: base)
    make_closed_with_exit(pnl: -6, exit_at: base + 1.day)
    make_closed_with_exit(pnl: 4,  exit_at: base + 2.days)

    stats = PaperTradeStats.for("stock")

    assert_in_delta 2.33, stats[:profit_factor], 0.01   # (10+4)/6
    assert_in_delta 6.0,  stats[:max_drawdown], 0.01    # (1.10 - 1.034)/1.10
    assert_in_delta 0.40, stats[:sharpe], 0.02          # mean 2.67 / std 6.60
    assert_in_delta 2.67, stats[:expectancy], 0.01      # = avg_pnl
  end

  # Inti perbaikan: posisi yang berjalan BERSAMAAN tidak boleh di-compound seolah
  # antre. Tiga trade yang tutup di hari yang sama = satu periode portofolio
  # (rata-rata +2,67%), jadi tak ada penurunan sama sekali. Versi lama menjumlahkan
  # pnl_pct dan melaporkan DD 6% dari hari yang bahkan berakhir untung.
  test "trade yang tutup di hari sama dirata-rata, bukan di-compound berurutan" do
    base = Time.current.beginning_of_day
    make_closed_with_exit(pnl: 10, exit_at: base)
    make_closed_with_exit(pnl: -6, exit_at: base + 1.minute)
    make_closed_with_exit(pnl: 4,  exit_at: base + 2.minutes)

    assert_in_delta 0.0, PaperTradeStats.for("stock")[:max_drawdown], 0.01
  end

  # Drawdown harus punya batas bawah -100%: bug lama (cum += pnl_pct) melaporkan
  # -4152% di dashboard karena menjumlahkan poin persen ribuan trade.
  test "drawdown tak pernah melewati 100% walau ratusan hari rugi beruntun" do
    base = Time.current.beginning_of_day - 400.days
    300.times { |i| make_closed_with_exit(pnl: -5, exit_at: base + i.days) }

    dd = PaperTradeStats.for("stock")[:max_drawdown]
    assert_operator dd, :<=, 100.0
    assert_operator dd, :>, 99.0   # -5%/hari selama 300 hari memang nyaris habis
  end

  test "profit factor nil when no losing trades" do
    make_trade(asset_type: "stock", pnl: 5)
    make_trade(asset_type: "stock", pnl: 3)
    stats = PaperTradeStats.for("stock")
    assert_nil stats[:profit_factor]
    assert_in_delta 0.0, stats[:max_drawdown], 0.01     # monotonically up
  end

  test "risk metrics nil with no closed trades" do
    stats = PaperTradeStats.for("crypto")
    assert_nil stats[:profit_factor]
    assert_nil stats[:max_drawdown]
    assert_nil stats[:sharpe]
  end
end

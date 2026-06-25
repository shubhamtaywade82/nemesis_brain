# frozen_string_literal: true

require "async"

class MotorCortex
  TRANCHE_COUNT = 4
  TRANCHE_DELAY = 15

  def initialize(nervous_system:, binance:)
    @ns = nervous_system
    @binance = binance
    @ns.subscribe(self)
  end

  def approved_order(order_data)
    plan = order_data[:plan]
    symbol = plan["symbol"] || "BTCUSDT"
    side = plan["side"]
    total = order_data[:size_usd]
    leverage = order_data[:leverage]
    stop_price = plan["invalidation_price"]
    entry_low = plan["entry_zone"]["low"]
    entry_high = plan["entry_zone"]["high"]

    log("Analysis: #{side} #{symbol} size=$#{total} leverage=#{leverage}x stop=#{stop_price} (no order sent)")

    @ns.broadcast(:order_analysis_logged, {
      symbol:,
      side:,
      size_usd: total,
      leverage:,
      stop_price:,
      entry_low:,
      entry_high:,
      status: "analyzed_only"
    })
  end
end

# frozen_string_literal: true

require "async"

class ExecutionTrader
  TRANCHE_COUNT = 4
  TRANCHE_DELAY = 15

  def initialize(event_bus:, binance:)
    @events = event_bus
    @binance = binance
    @events.subscribe(self)
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

    @events.broadcast(
      :order_analysis_logged,
      {
        symbol:,
        side:,
        size_usd: total,
        leverage:,
        stop_price:,
        entry_low:,
        entry_high:,
        status: "analyzed_only"
      }
    )
  end

  private

  def log(message)
    puts(QuantDesk::Log.colorize("[#{Time.now.strftime("%H:%M:%S")}] #{message}", :green))
  end
end

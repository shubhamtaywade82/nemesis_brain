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

    log("Executing #{side} order: #{symbol} size=$#{total} leverage=#{leverage}x stop=#{stop_price}") if NemesisBrain::VERBOSE_LOGS

    @binance.set_leverage(symbol:, leverage:)

    Async do |task|
      tranche_size = total / TRANCHE_COUNT
      total_qty = 0.0

      TRANCHE_COUNT.times do |index|
        task.async do
          wait_for_entry_zone(symbol, entry_low, entry_high)

          current_price = @binance.get_price(symbol)
          result = @binance.place_limit_order(
            symbol:,
            side: side == "LONG" ? "BUY" : "SELL",
            size_usd: tranche_size,
            price: current_price
          )

          qty = result["executedQty"].to_f
          total_qty += qty
          log("Tranche #{index + 1}/#{TRANCHE_COUNT} filled: #{qty} @ #{current_price}")
          sleep TRANCHE_DELAY
        end
      end

      task.async do
        sleep TRANCHE_COUNT * TRANCHE_DELAY + 5
        stop_side = side == "LONG" ? "SELL" : "BUY"
        @binance.place_stop_order(
          symbol:,
          side: stop_side,
          quantity: total_qty.round(3),
          stop_price:
        )
        log("Stop-loss placed at #{stop_price}")
        @ns.broadcast(:execution_complete, { symbol:, qty: total_qty, stop: stop_price })
      end
    end
  end

  private

  def log(message)
    puts(NemesisBrain::Log.colorize("[#{Time.now.strftime('%H:%M:%S')}] #{message}", :green))
  end

  def wait_for_entry_zone(symbol, low, high)
    loop do
      price = @binance.get_price(symbol)
      break if price.between?(low, high)

      sleep 0.5
    end
  end
end

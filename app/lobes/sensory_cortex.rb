# frozen_string_literal: true

require "async"
require "numo/narray"

class SensoryCortex
  CVD_WINDOW_SIZE = 200
  ABSORPTION_DELTA_THRESHOLD = 1_000_000
  ABSORPTION_PRICE_THRESHOLD = 0.05

  def initialize(nervous_system)
    @ns = nervous_system
    @cvd = []
    @prices = []
    @ob_bids = Numo::DFloat.zeros(20)
    @ob_asks = Numo::DFloat.zeros(20)
    @symbol = NemesisBrain::DEFAULT_SYMBOL
  end

  def start(symbol: NemesisBrain::DEFAULT_SYMBOL)
    @symbol = symbol
    return start_paper_feed if NemesisBrain::PAPER_MODE

    Async { stream_binance(symbol) }
  end

  private

  def log(message)
    puts(NemesisBrain::Log.colorize("[#{Time.now.strftime('%H:%M:%S')}] #{message}", :yellow))
  end

  def start_paper_feed
    Async do
      loop do
        simulate_absorption_signal
        sleep 30
      end
    end
  end

  def simulate_absorption_signal
    price = 50_000 + rand(-500..500)
    @prices << price
    @cvd << (rand > 0.5 ? 1_200_000 : -1_200_000)
    @cvd.shift if @cvd.size > CVD_WINDOW_SIZE

    @ns.broadcast(
      :tape_signal_detected,
      {
        type: :absorption,
        direction: @cvd.last.positive? ? :long : :short,
        delta: @cvd.last,
        price:,
        symbol: @symbol.upcase,
        ob_imbalance: 0.15,
        context: "Paper-mode absorption at #{price}"
      }
    )
  end

  def stream_binance(symbol)
    require "async/websocket/client"

    streams = [
      "#{symbol}@aggTrade",
      "#{symbol}@depth20",
      "#{symbol}@forceOrder"
    ]
    url = "#{NemesisBrain::BINANCE_WS}/stream?streams=#{streams.join('/')}"

    Async::WebSocket::Client.connect(url) do |connection|
      while (message = connection.read)
        route_event(Oj.load(message))
      end
    end
  end

  def route_event(payload)
    stream = payload["stream"]
    data = payload["data"]

    case stream
    when /aggTrade/ then process_tape(data)
    when /depth/ then update_orderbook(data)
    when /forceOrder/ then process_liquidation(data)
    end
  end

  def process_tape(trade)
    quantity = trade["q"].to_f
    price = trade["p"].to_f
    side = trade["m"] ? :sell : :buy

    delta = side == :buy ? quantity : -quantity
    @cvd << delta
    @cvd.shift if @cvd.size > CVD_WINDOW_SIZE
    @prices << price

    detect_absorption(delta)
  end

  def detect_absorption(_delta)
    return if @prices.size < 10

    cumulative_delta = @cvd.last(20).sum
    price_change_pct = ((@prices.last - @prices[-20]) / @prices[-20]).abs * 100
    return unless cumulative_delta.abs > ABSORPTION_DELTA_THRESHOLD
    return unless price_change_pct < ABSORPTION_PRICE_THRESHOLD

    direction = cumulative_delta.positive? ? :long : :short

    @ns.broadcast(
      :tape_signal_detected,
      {
        type: :absorption,
        direction:,
        delta: cumulative_delta,
        price: @prices.last,
        symbol: @symbol.upcase,
        ob_imbalance: calculate_ob_imbalance,
        context: "Delta=#{cumulative_delta.round(0)} absorbed at #{@prices.last}. Price unmoved."
      }
    )
  end

  def calculate_ob_imbalance
    bid_volume = @ob_bids.sum
    ask_volume = @ob_asks.sum
    return 0.0 if bid_volume + ask_volume == 0

    (bid_volume - ask_volume) / (bid_volume + ask_volume)
  end

  def process_liquidation(data)
    order = data["o"]
    symbol = order["s"]
    direction = (order["S"] == "BUY") ? "LONG" : "SHORT"
    usd_value = order["q"].to_f * order["ap"].to_f

    log("Liquidation: #{direction} #{symbol} $#{usd_value.round(2)}") if NemesisBrain::VERBOSE_LOGS

    @ns.broadcast(:liquidation_detected, { side: direction, usd_value: })
  end

  def update_orderbook(data)
    bids = data["b"].first(20).map { |level| level[1].to_f }
    asks = data["a"].first(20).map { |level| level[1].to_f }
    @ob_bids = Numo::DFloat.cast(bids)
    @ob_asks = Numo::DFloat.cast(asks)
  end
end

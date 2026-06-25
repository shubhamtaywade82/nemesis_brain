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
    Thread.new { stream_binance(symbol) }
  end

  def log(message)
    puts(NemesisBrain::Log.colorize("[#{Time.now.strftime('%H:%M:%S')}] #{message}", :yellow))
  end

  def stream_binance(symbol)
    require "websocket-client-simple"

    streams = [
      "#{symbol}@aggTrade",
      "#{symbol}@depth20",
      "#{symbol}@forceOrder"
    ]
    url = "#{NemesisBrain::BINANCE_WS}/stream?streams=#{streams.join('/')}"

    ws = WebSocket::Client::Simple.connect(url)
    ctx = self

    ws.on :message do |event|
      ctx.route_event(Oj.load(event.data))
    rescue Oj::ParseError => e
      ctx.log("WebSocket parse error: #{e.message}") if NemesisBrain::VERBOSE_LOGS
    rescue StandardError => e
      ctx.log("WebSocket message handler error: #{e.class}: #{e.message}") if NemesisBrain::VERBOSE_LOGS
    end
    ws.on :error do |event|
      if NemesisBrain::VERBOSE_LOGS
        puts(NemesisBrain::Log.colorize("WebSocket error: #{event.inspect}", :red))
        if event.respond_to?(:backtrace)
          puts event.backtrace.first(10).join("\n")
        end
      end
    end
    ws.on :close do |event|
      code = event.respond_to?(:code) ? event.code : "unknown"
      reason = event.respond_to?(:reason) ? event.reason : ""
      ctx.log("WebSocket closed: #{code} #{reason}") if NemesisBrain::VERBOSE_LOGS
      sleep 5
      stream_binance(symbol)
    end
  rescue StandardError => e
    log("WebSocket connection failed: #{e.class}: #{e.message}")
    sleep 5
    retry
  end

  def route_event(payload)
    return unless payload.is_a?(Hash)

    stream = payload["stream"]
    data = payload["data"]
    return unless stream && data

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

# frozen_string_literal: true

require "concurrent"
require_relative "../config/nemesis"

ROOT = File.expand_path("..", __dir__)

%w[
  app/signal_bus
  app/clients/binance_futures_client
  app/modules/trade_memory
  app/modules/market_scanner
  app/modules/strategy_engine
  app/modules/risk_manager
  app/modules/order_executor
  app/jobs/trade_review_job
].each do |path|
  require_relative "../#{path}"
end

module NemesisBrain
  class << self
    def boot(symbol: DEFAULT_SYMBOL, equity: DEFAULT_EQUITY)
      signal_bus = SignalBus.new
      binance = build_binance_client
      trade_memory = TradeMemory.new
      market_scanner = MarketScanner.new(signal_bus)
      StrategyEngine.new(signal_bus:, trade_memory:, binance:)
      RiskManager.new(signal_bus:, equity:, trade_memory:)
      OrderExecutor.new(signal_bus:, binance:)

      alpha_wave = Concurrent::TimerTask.new(execution_interval: 60) do
        pulse_alpha_wave(signal_bus, binance)
      end

      {
        signal_bus:,
        binance:,
        trade_memory:,
        market_scanner:,
        alpha_wave:,
        symbol:
      }
    end

    private

    def build_binance_client
      BinanceFuturesClient.new(
        api_key: ENV.fetch("BINANCE_KEY", "paper"),
        secret_key: ENV.fetch("BINANCE_SECRET", "paper"),
        base_url: BINANCE_REST
      )
    end

    def pulse_alpha_wave(signal_bus, binance)
      funding = binance.get_funding_rate("BTCUSDT")
      open_interest = binance.get_open_interest("BTCUSDT")
      signal_bus.broadcast(:macro_review_pulse, { funding_rates: funding, open_interest: })
    rescue StandardError => e
      warn "[AlphaWave] #{e.message}"
    end
  end
end

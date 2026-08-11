# frozen_string_literal: true

require "concurrent"
require_relative "../config/nemesis"

ROOT = File.expand_path("..", __dir__)

%w[
  app/event_bus
  app/clients/binance_futures_client
  app/desks/trade_journal
  app/desks/tape_reader
  app/desks/portfolio_manager
  app/desks/risk_manager
  app/desks/execution_trader
  app/jobs/nightly_trade_review
].each do |path|
  require_relative "../#{path}"
end

module Nemesis
  class << self
    def boot(symbol: DEFAULT_SYMBOL, equity: DEFAULT_EQUITY)
      event_bus = EventBus.new
      binance = build_binance_client
      journal = TradeJournal.new
      tape_reader = TapeReader.new(event_bus)
      PortfolioManager.new(event_bus:, journal:, binance:)
      RiskManager.new(event_bus:, equity:, journal:)
      ExecutionTrader.new(event_bus:, binance:)

      macro_pulse = Concurrent::TimerTask.new(execution_interval: 60) do
        publish_macro_snapshot(event_bus, binance)
      end

      {
        event_bus:,
        binance:,
        journal:,
        tape_reader:,
        macro_pulse:,
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

    def publish_macro_snapshot(event_bus, binance)
      funding = binance.get_funding_rate("BTCUSDT")
      open_interest = binance.get_open_interest("BTCUSDT")
      event_bus.broadcast(:macro_snapshot_updated, { funding_rates: funding, open_interest: })
    rescue StandardError => e
      warn "[MacroPulse] #{e.message}"
    end
  end
end

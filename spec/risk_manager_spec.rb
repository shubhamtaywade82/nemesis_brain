# frozen_string_literal: true

require "spec_helper"

RSpec.describe RiskManager do
  let(:signal_bus) { NervousSystem.new }
  let(:approved_orders) { [] }

  before do
    listener = Class.new do
      define_method(:initialize) { |buffer| @buffer = buffer }
      define_method(:approved_order) { |payload| @buffer << payload }
      define_method(:desk_closed) { |*_args| nil }
    end.new(approved_orders)

    signal_bus.subscribe(listener)
  end

  describe "trade plan gating" do
    it "approves A-grade plans with sufficient risk-reward" do
      risk_manager = described_class.new(signal_bus:, equity: 10_000)

      risk_manager.trade_plan_generated(
        "symbol" => "BTCUSDT",
        "side" => "LONG",
        "entry_zone" => { "low" => 49_900, "high" => 50_000 },
        "invalidation_price" => 49_600,
        "targets" => [50_800, 51_200],
        "setup_grade" => "A"
      )

      expect(approved_orders.length).to eq(1)
      expect(approved_orders.first[:size_usd]).to be > 0
      expect(approved_orders.first[:leverage]).to be_between(1, 20)
    end

    it "rejects plans below minimum risk-reward" do
      risk_manager = described_class.new(signal_bus:, equity: 10_000)

      risk_manager.trade_plan_generated(
        "symbol" => "BTCUSDT",
        "side" => "LONG",
        "entry_zone" => { "low" => 49_950, "high" => 50_000 },
        "invalidation_price" => 49_000,
        "targets" => [50_100, 50_200],
        "setup_grade" => "A"
      )

      expect(approved_orders).to be_empty
    end

    it "closes the desk after daily drawdown limit" do
      risk_manager = described_class.new(signal_bus:, equity: 10_000)

      risk_manager.trade_closed({ pnl_usd: -350 })

      expect(risk_manager.desk_open).to be(false)
    end

    it "sizes risk down after a run of same-side losses recorded in memory" do
      trade_memory = TradeMemory.new
      3.times do
        trade_memory.store_episode(
          symbol: "BTCUSDT", side: "long", entry_price: 50_000, exit_price: 49_500,
          pnl_r: -1.0, thesis: "Absorption long", context: "High delta, price pinned"
        )
      end
      risk_manager = described_class.new(signal_bus:, equity: 10_000, trade_memory:)

      risk_manager.trade_plan_generated(
        "symbol" => "BTCUSDT",
        "side" => "LONG",
        "entry_zone" => { "low" => 49_900, "high" => 50_000 },
        "invalidation_price" => 49_600,
        "targets" => [50_800, 51_200],
        "setup_grade" => "A"
      )

      expect(approved_orders.length).to eq(1)
      expect(approved_orders.first[:risk_pct]).to be < 1.0
    end
  end
end

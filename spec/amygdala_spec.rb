# frozen_string_literal: true

require "spec_helper"

RSpec.describe Amygdala do
  let(:nervous_system) { NervousSystem.new }
  let(:approved_orders) { [] }

  before do
    listener = Class.new do
      define_method(:initialize) { |buffer| @buffer = buffer }
      define_method(:approved_order) { |payload| @buffer << payload }
      define_method(:desk_closed) { |*_args| nil }
    end.new(approved_orders)

    nervous_system.subscribe(listener)
  end

  describe "trade plan gating" do
    it "approves A-grade plans with sufficient risk-reward" do
      amygdala = described_class.new(nervous_system:, equity: 10_000)

      amygdala.trade_plan_generated(
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
      amygdala = described_class.new(nervous_system:, equity: 10_000)

      amygdala.trade_plan_generated(
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
      amygdala = described_class.new(nervous_system:, equity: 10_000)

      amygdala.trade_closed({ pnl_usd: -350 })

      expect(amygdala.desk_open).to be(false)
    end
  end
end

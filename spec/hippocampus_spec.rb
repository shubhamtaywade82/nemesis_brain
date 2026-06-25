# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hippocampus do
  it "stores and recalls episodes from in-memory fallback" do
    memory = described_class.new

    memory.store_episode(
      symbol: "BTCUSDT",
      side: "long",
      entry_price: 50_000,
      exit_price: 49_500,
      pnl_r: -1.0,
      thesis: "Absorption long",
      context: "High delta, price pinned"
    )

    recalls = memory.recall("absorption long")
    expect(recalls).not_to be_empty
  end
end

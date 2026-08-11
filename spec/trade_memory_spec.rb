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

  it "returns all recent trades, not only losses" do
    memory = described_class.new

    memory.store_episode(
      symbol: "BTCUSDT", side: "long", entry_price: 50_000, exit_price: 50_500,
      pnl_r: 1.0, thesis: "Breakout long", context: "Strong momentum"
    )
    memory.store_episode(
      symbol: "BTCUSDT", side: "short", entry_price: 50_000, exit_price: 50_400,
      pnl_r: -0.8, thesis: "Fade short", context: "Failed rejection"
    )

    trades = memory.recent_trades(days: 7)

    expect(trades.length).to eq(2)
    expect(trades.map { |point| point[:payload][:win] }).to contain_exactly(true, false)
  end

  it "embeds episodes through the injected Ollama client when the LLM is enabled" do
    stub_const("NemesisBrain::LLM_ENABLED", true)
    ollama = instance_double(Ollama::Client, embeddings: instance_double(Ollama::Embeddings))
    allow(ollama.embeddings).to receive(:embed).and_return(Array.new(768, 0.1))
    memory = described_class.new(ollama:)

    memory.store_episode(
      symbol: "BTCUSDT", side: "long", entry_price: 50_000, exit_price: 50_500,
      pnl_r: 1.0, thesis: "Breakout long", context: "Strong momentum"
    )

    expect(ollama.embeddings).to have_received(:embed).with(
      model: NemesisBrain::EMBED_MODEL, input: a_string_including("Breakout long")
    )
  end
end

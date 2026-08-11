# frozen_string_literal: true

require "spec_helper"

RSpec.describe TradeJournal do
  it "records and finds similar trades from the in-memory fallback" do
    journal = described_class.new

    journal.record_trade(
      symbol: "BTCUSDT",
      side: "long",
      entry_price: 50_000,
      exit_price: 49_500,
      pnl_r: -1.0,
      thesis: "Absorption long",
      context: "High delta, price pinned"
    )

    matches = journal.similar_trades("absorption long")
    expect(matches).not_to be_empty
  end

  it "returns all recent trades, not only losses" do
    journal = described_class.new

    journal.record_trade(
      symbol: "BTCUSDT", side: "long", entry_price: 50_000, exit_price: 50_500,
      pnl_r: 1.0, thesis: "Breakout long", context: "Strong momentum"
    )
    journal.record_trade(
      symbol: "BTCUSDT", side: "short", entry_price: 50_000, exit_price: 50_400,
      pnl_r: -0.8, thesis: "Fade short", context: "Failed rejection"
    )

    trades = journal.recent_trades(days: 7)

    expect(trades.length).to eq(2)
    expect(trades.map { |entry| entry[:payload][:win] }).to contain_exactly(true, false)
  end

  it "embeds trades through the injected Ollama client when the LLM is enabled" do
    stub_const("Nemesis::LLM_ENABLED", true)
    ollama = instance_double(Ollama::Client, embeddings: instance_double(Ollama::Embeddings))
    allow(ollama.embeddings).to receive(:embed).and_return(Array.new(768, 0.1))
    journal = described_class.new(ollama:)

    journal.record_trade(
      symbol: "BTCUSDT", side: "long", entry_price: 50_000, exit_price: 50_500,
      pnl_r: 1.0, thesis: "Breakout long", context: "Strong momentum"
    )

    expect(ollama.embeddings).to have_received(:embed).with(
      model: Nemesis::EMBED_MODEL, input: a_string_including("Breakout long")
    )
  end
end

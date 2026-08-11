# frozen_string_literal: true

require "spec_helper"

RSpec.describe PortfolioManager do
  let(:event_bus) { EventBus.new }
  let(:journal) { instance_double(TradeJournal, similar_trades: []) }
  let(:generated_plans) { [] }

  before do
    listener = Class.new do
      define_method(:initialize) { |buffer| @buffer = buffer }
      define_method(:trade_plan_generated) { |payload| @buffer << payload }
    end.new(generated_plans)

    event_bus.subscribe(listener)
  end

  describe "#tape_signal_detected" do
    let(:signal) do
      {
        type: :absorption,
        direction: :long,
        price: 50_000,
        symbol: "BTCUSDT",
        context: "Delta=$1200000 absorbed at 50000. Price unmoved."
      }
    end

    it "skips plan generation without calling the LLM when disabled" do
      ollama = instance_spy(Ollama::Client)
      manager = described_class.new(event_bus:, journal:, ollama:)

      manager.tape_signal_detected(signal)

      expect(generated_plans).to be_empty
      expect(ollama).not_to have_received(:generate)
    end

    it "broadcasts a grade-A plan produced through the injected Ollama client" do
      stub_const("QuantDesk::LLM_ENABLED", true)
      plan = {
        "thesis" => "Absorption long", "symbol" => "BTCUSDT", "side" => "LONG",
        "entry_zone" => { "low" => 49_900, "high" => 50_000 },
        "invalidation_price" => 49_600, "targets" => [50_800, 51_200],
        "setup_grade" => "A", "confidence" => 0.8
      }
      ollama = instance_double(Ollama::Client, generate: plan)
      manager = described_class.new(event_bus:, journal:, ollama:)

      manager.tape_signal_detected(signal)

      expect(generated_plans).to eq([plan])
      expect(ollama).to have_received(:generate).with(
        hash_including(schema: PortfolioManager::TRADE_PLAN_SCHEMA, model: QuantDesk::REASONING_MODEL)
      )
    end

    it "does not broadcast plans graded below A" do
      stub_const("QuantDesk::LLM_ENABLED", true)
      plan = {
        "thesis" => "Weak setup", "symbol" => "BTCUSDT", "side" => "LONG",
        "entry_zone" => { "low" => 49_900, "high" => 50_000 },
        "invalidation_price" => 49_600, "targets" => [50_100],
        "setup_grade" => "C", "confidence" => 0.3
      }
      ollama = instance_double(Ollama::Client, generate: plan)
      manager = described_class.new(event_bus:, journal:, ollama:)

      manager.tape_signal_detected(signal)

      expect(generated_plans).to be_empty
    end

    it "recovers when the Ollama client raises" do
      stub_const("QuantDesk::LLM_ENABLED", true)
      ollama = instance_double(Ollama::Client)
      allow(ollama).to receive(:generate).and_raise(Ollama::TimeoutError, "timed out")
      manager = described_class.new(event_bus:, journal:, ollama:)

      expect { manager.tape_signal_detected(signal) }.not_to raise_error
      expect(generated_plans).to be_empty
    end
  end
end

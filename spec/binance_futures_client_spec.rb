# frozen_string_literal: true

require "spec_helper"

RSpec.describe BinanceFuturesClient do
  subject(:client) { described_class.new(api_key: "paper", secret_key: "paper") }

  describe "order placement" do
    it "raises TradeDisabledError instead of setting leverage" do
      expect { client.set_leverage(symbol: "BTCUSDT", leverage: 5) }
        .to raise_error(described_class::TradeDisabledError)
    end

    it "raises TradeDisabledError instead of placing a limit order" do
      expect { client.place_limit_order(symbol: "BTCUSDT", side: "buy", size_usd: 100, price: 50_000) }
        .to raise_error(described_class::TradeDisabledError)
    end

    it "raises TradeDisabledError instead of placing a stop order" do
      expect { client.place_stop_order(symbol: "BTCUSDT", side: "sell", quantity: 0.01, stop_price: 49_000) }
        .to raise_error(described_class::TradeDisabledError)
    end
  end

  describe "#analysis_only?" do
    it "is true for a paper API key" do
      expect(client.analysis_only?).to be(true)
    end

    it "is true for a configured key while QUANTDESK_PAPER_MODE is set (test env default)" do
      live_key_client = described_class.new(api_key: "real-key", secret_key: "real-secret")
      expect(live_key_client.analysis_only?).to be(true)
    end
  end
end

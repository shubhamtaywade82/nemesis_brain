# frozen_string_literal: true

require "binance_usdm"

class BinanceFuturesClient
  class TradeDisabledError < StandardError; end

  def initialize(api_key:, secret_key:, base_url: QuantDesk::BINANCE_REST)
    @api_key = api_key
    @paper = QuantDesk::PAPER_MODE || api_key == "paper"
    @client = Binance::USDM::Client.new(
      api_key:,
      secret_key:,
      testnet: base_url.include?("testnet")
    )
  end

  def get_price(symbol)
    return paper_price(symbol) if @paper

    @client.market.prices(symbol:)["price"].to_f
  rescue StandardError
    paper_price(symbol)
  end

  def get_funding_rate(symbol)
    result = @client.market.funding_rate_history(symbol:, limit: 1)
    result.is_a?(Array) && !result.empty? ? result.first : { "symbol" => symbol, "fundingRate" => "0.0000" }
  rescue StandardError
    { "symbol" => symbol, "fundingRate" => "0.0000" }
  end

  def get_open_interest(symbol)
    result = @client.market.open_interest(symbol:)
    result.is_a?(Hash) ? result : { "symbol" => symbol, "openInterest" => "0" }
  rescue StandardError
    { "symbol" => symbol, "openInterest" => "0" }
  end

  def public_get(path, params = {})
    @client.get(path, params:, signed: false)
  end

  def set_leverage(symbol:, leverage:)
    raise TradeDisabledError, "Order placement is disabled in analysis-only mode"
  end

  def place_limit_order(symbol:, side:, size_usd:, price:)
    raise TradeDisabledError, "Order placement is disabled in analysis-only mode"
  end

  def place_stop_order(symbol:, side:, quantity:, stop_price:)
    raise TradeDisabledError, "Order placement is disabled in analysis-only mode"
  end

  def dry_run_order(symbol:, side:, size_usd:, price:)
    quantity = (size_usd / price).round(3)
    {
      "symbol" => symbol,
      "side" => side.upcase,
      "type" => "LIMIT",
      "executedQty" => quantity,
      "price" => price.round(2),
      "status" => "dry_run"
    }
  end

  def analysis_only?
    !api_key_configured? || @paper
  end

  private

  def paper_price(symbol)
    @paper_prices ||= {}
    @paper_prices[symbol] ||= 0.0
  end

  def api_key_configured?
    @api_key && !@api_key.empty? && @api_key != "paper"
  end
end

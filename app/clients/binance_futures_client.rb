# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "openssl"
require "oj"

class BinanceFuturesClient
  class TradeDisabledError < StandardError; end
  def initialize(api_key:, secret_key:, base_url: NemesisBrain::BINANCE_REST, recv_window: 5000)
    @api_key = api_key
    @secret = secret_key
    @recv = recv_window
    @paper = NemesisBrain::PAPER_MODE || api_key == "paper"
    @conn = Faraday.new(base_url) do |faraday|
      faraday.request :retry, max: 3, interval: 0.5, retry_statuses: [429]
      faraday.adapter Faraday.default_adapter
    end
  end

  def get_price(symbol)
    return paper_price(symbol) if @paper

    public_get("/fapi/v1/ticker/price", symbol:)["price"].to_f
  rescue StandardError
    paper_price(symbol)
  end

  def get_funding_rate(symbol)
    result = public_get("/fapi/v1/fundingRate", symbol:, limit: 1)
    result.is_a?(Array) ? result.first : { "symbol" => symbol, "fundingRate" => "0.0000" }
  rescue StandardError
    { "symbol" => symbol, "fundingRate" => "0.0000" }
  end

  def get_open_interest(symbol)
    result = public_get("/fapi/v1/openInterest", symbol:)
    result.is_a?(Hash) ? result : { "symbol" => symbol, "openInterest" => "0" }
  rescue StandardError
    { "symbol" => symbol, "openInterest" => "0" }
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

  def public_get(path, params = {})
    response = @conn.get(path, params)
    Oj.load(response.body)
  end

  def api_key_configured?
    @api_key && !@api_key.empty? && @api_key != "paper"
  end

  def paper_order(symbol:, side:, size_usd: nil, price: nil, quantity: nil, stop_price: nil, type:)
    qty = quantity || (size_usd.to_f / price.to_f).round(3)
    {
      "symbol" => symbol,
      "side" => side.upcase,
      "type" => type,
      "executedQty" => qty,
      "price" => price,
      "stopPrice" => stop_price,
      "orderId" => SecureRandom.uuid
    }
  end

  def signed_get(path, params = {})
    payload = timestamped(params)
    payload[:signature] = sign(payload)
    response = @conn.get(path, payload, auth_header)
    Oj.load(response.body)
  end

  def signed_post(path, params = {})
    payload = timestamped(params)
    payload[:signature] = sign(payload)
    response = @conn.post(path, URI.encode_www_form(payload), auth_header)
    Oj.load(response.body)
  end

  def timestamped(params)
    params.merge(recvWindow: @recv, timestamp: (Time.now.to_f * 1000).to_i)
  end

  def auth_header
    { "X-MBX-APIKEY" => @api_key }
  end

  def sign(params)
    query = URI.encode_www_form(params.sort.to_h)
    OpenSSL::HMAC.hexdigest("SHA256", @secret, query)
  end
end

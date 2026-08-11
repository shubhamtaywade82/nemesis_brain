# frozen_string_literal: true

class PortfolioManager
  ATR_PERIOD = 14
  ATR_FALLBACK_PCT = 0.012

  TRADE_PLAN_SCHEMA = {
    "type" => "object",
    "required" => %w[thesis symbol side entry_zone invalidation_price targets setup_grade confidence],
    "properties" => {
      "thesis" => { "type" => "string" },
      "symbol" => { "type" => "string" },
      "side" => { "type" => "string", "enum" => %w[LONG SHORT] },
      "entry_zone" => {
        "type" => "object",
        "required" => %w[low high],
        "properties" => {
          "low" => { "type" => "number" },
          "high" => { "type" => "number" }
        }
      },
      "invalidation_price" => { "type" => "number" },
      "targets" => { "type" => "array", "items" => { "type" => "number" } },
      "setup_grade" => { "type" => "string", "enum" => %w[A B C] },
      "confidence" => { "type" => "number" }
    }
  }.freeze

  MACRO_BIAS_SCHEMA = {
    "type" => "object",
    "required" => %w[bias confidence notes],
    "properties" => {
      "bias" => { "type" => "string", "enum" => %w[LONG SHORT NEUTRAL] },
      "confidence" => { "type" => "number" },
      "notes" => { "type" => "string" }
    }
  }.freeze

  def initialize(event_bus:, journal:, binance: nil, ollama: Nemesis.ollama_client)
    @events = event_bus
    @journal = journal
    @binance = binance
    @ollama = ollama
    @events.subscribe(self)
  end

  def tape_signal_detected(signal)
    log("Signal received: #{signal[:type]} #{signal[:direction]} @ #{signal[:price]} (#{signal[:context]})") if Nemesis::VERBOSE_LOGS
    direction = signal[:direction]
    price = signal[:price]
    context = signal[:context]
    symbol = signal[:symbol]

    similar_trades = @journal.similar_trades("#{direction} absorption #{context}")
    log("Journal recall returned #{similar_trades.length} similar trades") if Nemesis::VERBOSE_LOGS && similar_trades.any?
    atr_pct = fetch_atr_pct(symbol || "BTCUSDT")
    trade_plan = generate_trade_plan(
      symbol: symbol || "BTCUSDT",
      direction:,
      price:,
      atr_pct:,
      context:,
      similar_trades:
    )

    if trade_plan
      if trade_plan["setup_grade"] == "A"
        log("PM: Grade A plan for #{trade_plan['side']} #{symbol}")
        @events.broadcast(:trade_plan_generated, trade_plan)
      else
        log("PM: Grade #{trade_plan['setup_grade']} — skipped")
      end
    else
      log("PM: No trade plan for #{symbol} #{direction.to_s.upcase}")
    end
  end

  def macro_snapshot_updated(snapshot)
    unless Nemesis::LLM_ENABLED
      log("PM: LLM disabled, skipping macro bias update")
      return
    end

    prompt = macro_bias_prompt(snapshot)
    log("Macro bias prompt sent to LLM") if Nemesis::VERBOSE_LOGS
    bias = ask_llm(prompt, MACRO_BIAS_SCHEMA)
    log("Macro bias result: #{Oj.dump(bias)}") if Nemesis::VERBOSE_LOGS
    @events.broadcast(:macro_bias_updated, bias)
  rescue Ollama::Error => e
    log("PM: Macro bias skip (#{e.message})")
  end

  private

  def generate_trade_plan(symbol:, direction:, price:, atr_pct:, context:, similar_trades:)
    unless Nemesis::LLM_ENABLED
      log("LLM disabled — skipping plan generation for #{symbol} #{direction.to_s.upcase}")
      return nil
    end

    prompt = trade_plan_prompt(symbol:, direction:, price:, atr_pct:, context:, similar_trades:)

    log("Prompting LLM for #{symbol} #{direction.to_s.upcase} plan") if Nemesis::VERBOSE_LOGS
    plan = ask_llm(prompt, TRADE_PLAN_SCHEMA)
    log("Trade plan result: #{Oj.dump(plan)}") if Nemesis::VERBOSE_LOGS
    plan
  rescue Ollama::Error => e
    log("Trade plan generation failed: #{e.message}")
    nil
  end

  def trade_plan_prompt(symbol:, direction:, price:, atr_pct:, context:, similar_trades:)
    <<~PROMPT
      You are the Portfolio Manager of a crypto prop desk.
      Signal: #{direction.to_s.upcase} absorption at #{price}.
      Symbol: #{symbol}
      Context: #{context}
      Current ATR: #{(atr_pct * 100).round(2)}%
      #{similar_trades_summary(similar_trades)}

      Respond ONLY as JSON matching this schema:
      #{Oj.dump(TRADE_PLAN_SCHEMA)}
    PROMPT
  end

  def macro_bias_prompt(snapshot)
    <<~PROMPT
      Macro environment review.
      Funding rates: #{Oj.dump(snapshot[:funding_rates])}
      Open interest trend: #{Oj.dump(snapshot[:open_interest])}
      What is the dominant market bias right now?

      Respond ONLY as JSON matching this schema:
      #{Oj.dump(MACRO_BIAS_SCHEMA)}
    PROMPT
  end

  def similar_trades_summary(similar_trades)
    return "No relevant past trades found." if similar_trades.empty?

    "Similar past trades:\n#{similar_trades.join("\n")}"
  end

  # Ollama's structured-output mode validates and parses the JSON for us,
  # so this always returns the schema-shaped Hash — never raw text.
  def ask_llm(prompt, schema)
    @ollama.generate(prompt:, schema:, model: Nemesis::REASONING_MODEL)
  end

  def fetch_atr_pct(symbol)
    klines = @binance&.public_get("/fapi/v1/klines", symbol: symbol.upcase, interval: "5m", limit: ATR_PERIOD + 1)
    return ATR_FALLBACK_PCT unless klines.is_a?(Array) && klines.size >= ATR_PERIOD + 1

    true_ranges = klines.each_cons(2).map { |prev_kline, kline| true_range(prev_kline, kline) }
    average_true_range = true_ranges.sum / true_ranges.size
    mid_price = klines.last[4].to_f

    (average_true_range / mid_price).clamp(0.005, 0.05)
  rescue StandardError => e
    log("ATR calculation failed: #{e.message}") if Nemesis::VERBOSE_LOGS
    ATR_FALLBACK_PCT
  end

  def true_range(prev_kline, kline)
    high = kline[2].to_f
    low = kline[3].to_f
    prev_close = prev_kline[4].to_f
    [high - low, (high - prev_close).abs, (low - prev_close).abs].max
  end

  def log(message)
    puts(Nemesis::Log.colorize("[#{Time.now.strftime('%H:%M:%S')}] #{message}", :cyan))
  end
end

# frozen_string_literal: true

class PrefrontalCortex
  TRADE_PLAN_SCHEMA = {
    type: "object",
    properties: {
      thesis: { type: "string" },
      symbol: { type: "string" },
      side: { type: "string", enum: %w[LONG SHORT] },
      entry_zone: {
        type: "object",
        properties: {
          low: { type: "number" },
          high: { type: "number" }
        },
        required: %w[low high]
      },
      invalidation_price: { type: "number" },
      targets: { type: "array", items: { type: "number" } },
      setup_grade: { type: "string", enum: %w[A B C] },
      confidence: { type: "number" }
    },
    required: %w[thesis symbol side entry_zone invalidation_price targets setup_grade confidence]
  }.freeze

  def initialize(nervous_system:, hippocampus:)
    @ns = nervous_system
    @memory = hippocampus
    @ns.subscribe(self)
  end

  def tape_signal_detected(signal)
    direction = signal[:direction]
    price = signal[:price]
    context = signal[:context]
    symbol = signal[:symbol]

    memories = @memory.recall("#{direction} absorption #{context}")
    atr_pct = fetch_atr_pct(symbol || "BTCUSDT")
    trade_plan = generate_trade_plan(
      symbol: symbol || "BTCUSDT",
      direction:,
      price:,
      atr_pct:,
      context:,
      memories:
    )

    if trade_plan["setup_grade"] == "A"
      log("PM: Grade A plan for #{trade_plan['side']} #{symbol}")
      @ns.broadcast(:trade_plan_generated, trade_plan)
    else
      log("PM: Grade #{trade_plan['setup_grade']} — skipped")
    end
  end

  def alpha_wave_pulse(snapshot)
    unless NemesisBrain::LLM_ENABLED
      log("PM: LLM disabled, skipping macro bias pulse")
      return
    end

    funding_rates = snapshot[:funding_rates]
    open_interest = snapshot[:open_interest]
    prompt = <<~PROMPT
      Macro environment review.
      Funding rates: #{Oj.dump(funding_rates)}
      Open interest trend: #{Oj.dump(open_interest)}
      What is the dominant market bias right now?
      JSON: { "bias": "LONG|SHORT|NEUTRAL", "confidence": float, "notes": "string" }
    PROMPT

    bias = Oj.load(clean_llm_json(ask_llm(prompt)))
    @ns.broadcast(:macro_bias_updated, bias)
  rescue StandardError => e
    log("PM: Macro bias skip (#{e.message})")
  end

  private

  def generate_trade_plan(symbol:, direction:, price:, atr_pct:, context:, memories:)
    return paper_trade_plan(symbol:, direction:, price:) unless NemesisBrain::LLM_ENABLED

    memory_text = if memories.any?
                    "Past similar episodes:\n#{memories.join("\n")}"
                  else
                    "No relevant past episodes found."
                  end

    prompt = <<~PROMPT
      You are the Portfolio Manager of a crypto prop desk.
      Signal: #{direction.to_s.upcase} absorption at #{price}.
      Symbol: #{symbol}
      Context: #{context}
      Current ATR: #{(atr_pct * 100).round(2)}%
      #{memory_text}

      Respond ONLY as JSON matching this schema:
      #{Oj.dump(TRADE_PLAN_SCHEMA)}
    PROMPT

    Oj.load(clean_llm_json(ask_llm(prompt, TRADE_PLAN_SCHEMA)))
  rescue StandardError
    paper_trade_plan(symbol:, direction:, price:)
  end

  def paper_trade_plan(symbol:, direction:, price:)
    stop_distance = price * 0.008
    side = direction.to_s.upcase
    invalidation = side == "LONG" ? price - stop_distance : price + stop_distance
    target1 = side == "LONG" ? price + stop_distance : price - stop_distance
    target2 = side == "LONG" ? price + (stop_distance * 3) : price - (stop_distance * 3)

    {
      "thesis" => "Paper-mode #{side} absorption setup",
      "symbol" => symbol,
      "side" => side,
      "entry_zone" => { "low" => price * 0.999, "high" => price * 1.001 },
      "invalidation_price" => invalidation.round(2),
      "targets" => [target1.round(2), target2.round(2)],
      "setup_grade" => "A",
      "confidence" => 0.75
    }
  end

  def ask_llm(prompt, schema = nil)
    chat = RubyLLM.chat(model: NemesisBrain::REASONING_MODEL, provider: :ollama)
    chat = chat.with_schema(schema) if schema
    chat.ask(prompt).content
  end

  def fetch_atr_pct(_symbol)
    0.012
  end

  def log(message)
    puts "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
  end

  def clean_llm_json(raw)
    raw.to_s.gsub(/^```json\n?/, "").gsub(/\n?```$/, "").strip
  end
end

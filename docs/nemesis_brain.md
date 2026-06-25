# Nemesis — Cognitive Trading Brain

> **Nemesis Framework · Ruby + Ollama Cloud**
>
> A complete architecture for building an autonomous crypto futures agent that perceives, reasons, remembers, and executes — like a professional prop trading desk, not a script.

**Tech Stack:** `Ollama Cloud LLM` · `ruby_llm` · `langchainrb` · `Binance FAPI` · `async-websocket` · `Qdrant RAG` · `pgvector` · `Kelly Criterion` · `CVD / Order Flow`

---

## Table of Contents

1. [Architecture](#architecture)
2. [Setup & Configuration](#setup--configuration)
3. [Sensory Cortex](#sensory-cortex)
4. [Reasoning & Intent](#reasoning--intent)
5. [Hippocampus](#hippocampus)
6. [Risk CRO](#risk-cro)
7. [Execution](#execution)
8. [Daily Lifecycle](#daily-lifecycle)
9. [Gem Stack](#gem-stack)

---

## Architecture

### The Cognitive Architecture

Nemesis maps biological brain lobes to institutional trading desk roles. Each lobe is a decoupled service communicating via a Pub/Sub nervous system — never direct calls.

#### Architecture Diagram

```
Binance WebSocket  ──────►  SensoryCortex  ──( tape tick )──►  NervousSystem
                                                                               │
                          ┌────────────────────────────────────────────────────┘
                          │
                          ├──► :market_regime_changed  ──►  PrefrontalCortex (Ollama llama3:70b)
                          │                                                    │ :intent_generated
                          │                                                    ▼
                          │                                           Amygdala (CRO)
                          │                                                    │ :approved_order
                          │                                                    ▼
                          │                                           MotorCortex (Iceberg TWAP)
                          │                                                    │ :trade_executed
                          │                                                    ▼
                          └──────────────────────────────────────────►  Hippocampus (Qdrant)
                                                                             │
                          ◄───────────────────────────────────────────  episodic recall on next signal
```

### Brain Lobes

#### 👁️ Sensory Cortex — Tape Reader
- **Role:** QUANT / MARKET DATA
- **Description:** Reads raw Binance WebSocket streams: trades, order book L2, funding rates, liquidation events. Computes CVD (Cumulative Volume Delta) and detects absorption / exhaustion in real time.
- **Tech:** `async-websocket` · `numo-narray` · `redis pub/sub`

#### 🧠 Prefrontal Cortex — Portfolio Manager
- **Role:** SYSTEM 2 · OLLAMA CLOUD
- **Description:** The LLM reasoning layer. Synthesises tape signals + episodic memories into a structured Trade Plan with entry zone, invalidation price, R:R targets, and a setup grade. Only "A" grade plans pass to CRO.
- **Tech:** `ruby_llm` · `llama3:70b` · `JSON mode`

#### 😤 Amygdala — Chief Risk Officer
- **Role:** SYSTEM 1 · VETO POWER
- **Description:** Hardcoded survival rules. Enforces Kelly Criterion sizing, ATR-based stop distance, VaR, daily drawdown kill-switch (3% of equity), and cross-asset correlation limits. Has absolute veto over the LLM.
- **Tech:** `kill switch` · `kelly criterion` · `matrix`

#### ⚡ Motor Cortex — Execution Trader
- **Role:** TWAP / ICEBERG ALGOS
- **Description:** Never market-orders large size. Splits into 4 async tranches, places post-only limit orders at bid/ask to minimise slippage and avoid triggering HFT detection. Uses HMAC-signed Binance FAPI.
- **Tech:** `async` · `faraday-retry` · `HMAC-SHA256`

#### 🗃️ Hippocampus — Episodic Memory
- **Role:** RAG · VECTOR STORE
- **Description:** Stores every closed trade as a vector embedding of market context + outcome. On each new signal the Cortex performs cosine similarity recall — enabling "déjà vu" about past liquidation cascades or winning setups.
- **Tech:** `qdrant-ruby` · `nomic-embed-text` · `pgvector`

#### 📡 NervousSystem — Event Bus
- **Role:** PUB/SUB DECOUPLING
- **Description:** Lobes never call each other directly. Everything flows through the NervousSystem pub/sub bus using wisper. This makes each lobe independently testable, replaceable, and failure-isolated.
- **Tech:** `wisper` · `concurrent-ruby` · `redis streams`

> **Key Design Principle:** The Amygdala (System 1, hardcoded rules) always has veto power over the Prefrontal Cortex (System 2, LLM reasoning). This prevents the LLM from hallucinating a "great trade" during a volatility spike or when daily drawdown limits are already breached.

---

## Setup & Configuration

Ollama Cloud API, gem installation, and environment wiring. Uses the OpenAI-compatible endpoint for maximum compatibility with ruby_llm.

### Ollama Cloud API

Ollama Cloud runs models on datacenter GPUs — no local GPU needed. The native endpoint is `https://ollama.com/api`. For tool-calling and JSON mode, use the OpenAI-compatible endpoint at `https://ollama.com/v1`. Authentication is via the `OLLAMA_API_KEY` environment variable.

### Gemfile

```ruby
ruby ">= 3.3.0"
source "https://rubygems.org"

# ── LLM & Agent Layer ────────────────────────────────
gem "ruby_llm",              "~> 1.2"   # Unified Ollama Cloud interface + tool calling
gem "langchainrb",           "~> 0.8"   # ReAct agent, vectorstore integrations
gem "oj",                    "~> 3.16"  # Fast JSON for LLM structured outputs

# ── Nervous System (Concurrency & Events) ────────────
gem "wisper",                "~> 2.0"   # Pub/Sub between brain lobes
gem "concurrent-ruby",       "~> 1.2"   # Thread-safe alpha-wave background loops
gem "async",                 "~> 2.8"   # Non-blocking I/O for WebSockets + TWAP
gem "async-websocket",       "~> 0.25"  # Binance FAPI streaming

# ── Market Data & Execution ───────────────────────────
gem "faraday",               "~> 2.9"   # HTTP client for Binance REST
gem "faraday-retry",         "~> 2.2"   # Auto-retry on 429 TooManyRequests

# ── Memory & State ────────────────────────────────────
gem "qdrant-ruby",           "~> 1.2"   # Vector DB for episodic memory (RAG)
gem "redis",                 "~> 5.0"   # Working memory & state sync
gem "pg",                    "~> 1.5"   # Long-term trade logs + pgvector

# ── Quant Math ────────────────────────────────────────
gem "numo-narray",           "~> 0.9"   # N-dimensional arrays (CVD, order book math)
gem "talib-ruby"                         # ATR, RSI, MACD for signal generation
gem "descriptive_statistics"             # VaR, std-dev, correlation

# ── Observability ─────────────────────────────────────
gem "prometheus-client"                  # Metrics: intent accuracy, slippage, P&L
gem "sentry-ruby"                        # Exception tracking
```

### config/nemesis.rb

```ruby
require "ruby_llm"

RubyLLM.configure do |c|
  c.ollama_api_key = ENV["OLLAMA_API_KEY"]
  c.ollama_api_base = "https://ollama.com/v1"  # OpenAI-compatible endpoint
end

# Primary reasoning model (cloud GPU — no local GPU needed)
REASONING_MODEL = "llama3:70b"

# Embedding model for episodic memory vectors
EMBED_MODEL     = "nomic-embed-text"

# Binance Futures base URLs
BINANCE_REST = "https://fapi.binance.com"
BINANCE_WS   = "wss://fstream.binance.com"

# ⚠️  Always test on testnet first:
# BINANCE_REST = "https://testnet.binancefuture.com"
```

> **⚠️ Testnet first.** Run exclusively on `testnet.binancefuture.com` for at least 2–4 weeks. Log every LLM decision, tool call, and API response before touching real capital.

---

## Sensory Cortex

### Sensory Cortex — Tape Reader

Real-time Binance FAPI WebSocket ingestion. Professionals read CVD (Cumulative Volume Delta) and order book absorption — not lagging indicators.

#### What CVD Tells You

- **Delta** = market buys − market sells per interval.
- **Absorption** = high delta but price doesn't move → limit orders are eating aggression. This is a high-conviction signal that a large player is defending a level.
- **Exhaustion** = delta diverges from price direction → momentum is fading.

### app/lobes/sensory_cortex.rb

```ruby
require "async"
require "async/websocket/client"
require "numo/narray"

class SensoryCortex
  CVD_WINDOW_SIZE = 200
  ABSORPTION_DELTA_THRESHOLD = 1_000_000  # USDT notional
  ABSORPTION_PRICE_THRESHOLD = 0.05        # % — price must NOT move

  def initialize(nervous_system)
    @ns       = nervous_system
    @cvd      = []
    @prices   = []
    @ob_bids  = Numo::DFloat.zeros(20)
    @ob_asks  = Numo::DFloat.zeros(20)
  end

  def start(symbol: "btcusdt")
    Async do
      streams = [
        "#{symbol}@aggTrade",   # Raw tape (aggressive orders)
        "#{symbol}@depth20",     # L2 order book (top 20 levels)
        "#{symbol}@forceOrder"   # Liquidation events
      ]

      url = "#{BINANCE_WS}/stream?streams=#{streams.join('/')}"

      Async::WebSocket::Client.connect(url) do |conn|
        while (msg = conn.read)
          payload = Oj.load(msg)
          route_event(payload)
        end
      end
    end
  end

  private

  def route_event(payload)
    stream = payload["stream"]
    data   = payload["data"]

    case stream
    when /aggTrade/  then process_tape(data)
    when /depth/     then update_orderbook(data)
    when /forceOrder/ then process_liquidation(data)
    end
  end

  def process_tape(trade)
    qty   = trade["q"].to_f
    price = trade["p"].to_f
    side  = trade["m"] ? :sell : :buy  # m=true means maker=buyer → market sell

    delta = side == :buy ? qty : -qty
    @cvd  << delta
    @cvd.shift if @cvd.size > CVD_WINDOW_SIZE
    @prices << price

    detect_absorption(delta)
  end

  def detect_absorption(delta)
    return if @prices.size < 10

    cumulative_delta = @cvd.last(20).sum
    price_change_pct = ((@prices.last - @prices[-20]) / @prices[-20]).abs * 100

    if cumulative_delta.abs > ABSORPTION_DELTA_THRESHOLD &&
       price_change_pct < ABSORPTION_PRICE_THRESHOLD

      direction = cumulative_delta > 0 ? :long : :short
      ob_imbalance = calculate_ob_imbalance

      @ns.broadcast(:tape_signal_detected,
        type:         :absorption,
        direction:    direction,
        delta:        cumulative_delta,
        price:        @prices.last,
        ob_imbalance: ob_imbalance,
        context:      "Delta=#{cumulative_delta.round(0)} absorbed at #{@prices.last}. Price unmoved."
      )
    end
  end

  def calculate_ob_imbalance
    bid_volume = @ob_bids.sum
    ask_volume = @ob_asks.sum
    return 0.0 if bid_volume + ask_volume == 0
    (bid_volume - ask_volume) / (bid_volume + ask_volume)  # -1.0 to +1.0
  end

  def process_liquidation(data)
    order = data["o"]
    side  = order["S"]   # SELL = long liquidation, BUY = short liquidation
    usd   = order["q"].to_f * order["ap"].to_f

    @ns.broadcast(:liquidation_detected, side: side, usd_value: usd)
  end

  def update_orderbook(data)
    bids = data["b"].first(20).map { |b| b[1].to_f }
    asks = data["a"].first(20).map { |a| a[1].to_f }
    @ob_bids = Numo::DFloat.cast(bids)
    @ob_asks = Numo::DFloat.cast(asks)
  end
end
```

---

## Reasoning & Intent

### Prefrontal Cortex — Reasoning & Intent

The LLM reasoning layer. Classifies intent into structured JSON, retrieves episodic memories, and generates a formal Trade Plan with defined R:R before anything else happens.

#### Two-Stage Reasoning

- **Stage 1 — Intent Classification:** Convert any input (tape signal, manual prompt, macro alert) into a structured JSON intent object using Ollama's JSON mode.
- **Stage 2 — Trade Plan Generation:** The Portfolio Manager uses that intent + episodic memories to formulate entry zone, invalidation, targets, and a setup grade. Only "A" grade plans advance.

### app/lobes/prefrontal_cortex.rb

```ruby
class PrefrontalCortex
  include Wisper::Publisher

  INTENT_SCHEMA = {
    type: "object",
    properties: {
      intent:   { type: "string", enum: ["open_position", "close_position", "analyze_market", "unknown"] },
      symbol:   { type: "string" },
      side:     { type: "string", enum: ["long", "short"] },
      leverage: { type: "integer" },
      reason:   { type: "string" }
    },
    required: ["intent"]
  }

  def initialize(nervous_system:, hippocampus:)
    @ns     = nervous_system
    @memory = hippocampus
    @llm    = RubyLLM.chat(model: REASONING_MODEL, provider: :ollama)

    @ns.subscribe(self, on: :tape_signal_detected)
    @ns.subscribe(self, on: :alpha_wave_pulse)    # 60s background heartbeat
  end

  # ── Triggered by SensoryCortex ──────────────────────────────
  def tape_signal_detected(type:, direction:, delta:, price:, context:, **rest)
    memories   = @memory.recall("#{direction} absorption #{context}")
    atr        = fetch_atr_pct(rest[:symbol] || "BTCUSDT")
    trade_plan = generate_trade_plan(direction, price, atr, context, memories)

    if trade_plan["setup_grade"] == "A"
      @ns.broadcast(:trade_plan_generated, trade_plan)
    else
      log("PM: Grade #{trade_plan['setup_grade']} — skipped. Waiting for better setup.")
    end
  end

  def alpha_wave_pulse(funding_rates:, open_interest:)
    prompt = <<~P
      Macro environment review.
      Funding rates: #{funding_rates.to_json}
      Open interest trend: #{open_interest.to_json}
      What is the dominant market bias right now? Any concerning signals?
      JSON: { "bias": "LONG|SHORT|NEUTRAL", "confidence": float, "notes": "string" }
    P
    bias = Oj.load(ask_llm(prompt))
    @ns.broadcast(:macro_bias_updated, bias)
  end

  private

  def generate_trade_plan(direction, price, atr_pct, context, memories)
    memory_text = memories.any? ?
      "Past similar episodes:
#{memories.join("
")}" :
      "No relevant past episodes found."

    prompt = <<~PROMPT
      You are the Portfolio Manager of a crypto prop desk.
      Signal: #{direction.upcase} absorption at #{price}.
      Context: #{context}
      Current ATR: #{(atr_pct * 100).round(2)}%
      #{memory_text}

      Rules:
      - Entry must be near the absorption zone (within 0.1%)
      - Invalidation goes WHERE THE THESIS IS WRONG (below absorption node for LONG)
      - Target 1 at 1R, Target 2 at 3R minimum
      - Grade A = clear absorption + OB confluence + macro aligned
        Grade B = absorption only, no confluence
        Grade C = ambiguous / avoid

      Respond ONLY as JSON:
      {
        "thesis": "string",
        "side": "LONG|SHORT",
        "entry_zone": {"low": float, "high": float},
        "invalidation_price": float,
        "targets": [float, float],
        "setup_grade": "A|B|C",
        "confidence": float
      }
    PROMPT

    Oj.load(ask_llm(prompt))
  end

  def ask_llm(prompt)
    # Fresh chat each call — stateless for determinism
    chat = RubyLLM.chat(model: REASONING_MODEL, provider: :ollama)
    chat.ask(prompt, response_format: { type: "json_object" }).content
  end

  def fetch_atr_pct(symbol)
    0.012  # Placeholder — in prod: calculate from last 14 candles via talib-ruby
  end
end
```

---

## Hippocampus

### Hippocampus — Episodic Memory & RAG

Unlike standard agents that forget everything on restart, Nemesis embeds every trade's full market context as a vector and performs cosine recall — enabling genuine learning from past mistakes.

### app/lobes/hippocampus.rb

```ruby
class Hippocampus
  COLLECTION = "nemesis_episodes"
  VECTOR_DIM  = 768  # nomic-embed-text output dimension

  def initialize
    @qdrant   = Qdrant::Client.new(
      url:     ENV["QDRANT_URL"],
      api_key: ENV["QDRANT_API_KEY"]
    )
    @embedder = RubyLLM.embed(model: EMBED_MODEL, provider: :ollama)
    ensure_collection_exists
  end

  # Called after every closed trade
  def store_episode(symbol:, side:, entry_price:, exit_price:, pnl_r:, thesis:, context:)
    outcome  = pnl_r >= 0 ? "WIN (#{pnl_r.round(2)}R)" : "LOSS (#{pnl_r.round(2)}R)"
    text = <<~T
      Trade: #{symbol} #{side.upcase} at #{entry_price} → #{exit_price}
      Thesis: #{thesis}
      Market context: #{context}
      Outcome: #{outcome}
    T

    vector = embed(text)

    @qdrant.points.upsert(
      collection_name: COLLECTION,
      points: [{
        id:      SecureRandom.uuid,
        vector:  vector,
        payload: {
          text:       text,
          pnl_r:      pnl_r,
          symbol:     symbol,
          timestamp:  Time.now.to_i,
          win:        pnl_r >= 0
        }
      }]
    )
  end

  # Called by PrefrontalCortex before generating a trade plan
  def recall(market_context, limit: 4, min_score: 0.72)
    vector  = embed(market_context)
    results = @qdrant.points.search(
      collection_name: COLLECTION,
      vector:          vector,
      limit:           limit,
      score_threshold: min_score
    )

    (results.dig("result") || []).map do |hit|
      payload = hit["payload"]
      "[Score:#{hit['score'].round(2)}] #{payload['text'].strip}"
    end
  end

  # Nightly post-mortem: fetch recent losing trades for LLM review
  def recent_losses(days: 1, limit: 10)
    cutoff = (Time.now - days * 86400).to_i
    # Scroll with filter — Qdrant supports payload filtering
    @qdrant.points.scroll(
      collection_name: COLLECTION,
      filter: {
        must: [
          { key: "win",       match: { value: false } },
          { key: "timestamp", range: { gte: cutoff } }
        ]
      },
      limit: limit,
      with_payload: true
    ).dig("result", "points") || []
  end

  private

  def embed(text)
    @embedder.embed(text).embedding
  end

  def ensure_collection_exists
    existing = @qdrant.collections.list["result"]["collections"].map { |c| c["name"] }
    return if existing.include?(COLLECTION)

    @qdrant.collections.create(
      collection_name: COLLECTION,
      vectors: { size: VECTOR_DIM, distance: "Cosine" }
    )
  end
end
```

> **Why this works:** Standard agents have no memory between restarts. Nemesis recalls semantically similar past trades — e.g., a long absorption signal that led to a stop-hunt 3 weeks ago — and injects that context into the LLM's reasoning before the trade plan is generated.

---

## Risk CRO

### Amygdala — Chief Risk Officer

The veto layer. Hardcoded survival rules that the LLM cannot override. Uses Kelly Criterion, ATR-based stop sizing, and correlation-adjusted position limits.

#### Risk Philosophy

| ❌ What Retail Does | ✅ What Nemesis Does |
|---|---|
| "Let's use 10x leverage on this trade." Arbitrary leverage with no connection to stop distance or account risk. | Risk $100 (1% of $10k equity). Stop distance = 0.8% from entry. Position size = $100 / 0.008 = $12,500 notional. Leverage is derived, not chosen. |
| Already down 3% today? Keep trading "to make it back." This is revenge trading — the most common account blowup pattern. | Daily drawdown ≥ 3% of equity triggers a hard desk close. No more trades until next session. Non-negotiable, LLM cannot override. |

### app/lobes/amygdala.rb

```ruby
require "matrix"
require "descriptive_statistics"

class Amygdala
  MAX_RISK_PER_TRADE = 0.01  # 1% of equity per trade
  MAX_DAILY_DRAWDOWN = 0.03  # 3% daily loss = desk closed
  MAX_LEVERAGE       = 20    # Hard cap regardless of sizing math
  MIN_RR_RATIO       = 2.0  # Must have 2:1 minimum R:R to proceed

  def initialize(nervous_system:, equity:)
    @ns        = nervous_system
    @equity    = equity
    @session_pnl = 0.0
    @desk_open = true

    @ns.subscribe(self, on: :trade_plan_generated)
    @ns.subscribe(self, on: :trade_closed)
  end

  def trade_plan_generated(plan)
    unless @desk_open
      log("🛑 AMYGDALA: Desk closed (daily drawdown limit hit). Rejecting.")
      return
    end

    entry   = plan["entry_zone"]["high"].to_f
    stop    = plan["invalidation_price"].to_f
    target1 = plan["targets"][0].to_f
    target2 = plan["targets"][1].to_f

    stop_distance    = (entry - stop).abs / entry
    reward_distance  = (target1 - entry).abs / entry
    rr_ratio         = reward_distance / stop_distance

    if rr_ratio < MIN_RR_RATIO
      log("🛑 AMYGDALA: R:R #{rr_ratio.round(2)} < #{MIN_RR_RATIO} minimum. Rejected.")
      return
    end

    # Kelly Criterion sizing (fractional Kelly = 0.25 for safety)
    win_rate       = 0.45  # Conservative prior — update from trade history
    kelly_fraction = (win_rate - ((1 - win_rate) / rr_ratio)) * 0.25
    kelly_fraction = kelly_fraction.clamp(0.0, MAX_RISK_PER_TRADE)

    risk_amount     = @equity * kelly_fraction
    position_size   = risk_amount / stop_distance
    leverage        = (position_size / @equity).ceil.clamp(1, MAX_LEVERAGE)

    # Cross-asset correlation penalty
    correlation_factor = correlation_penalty(plan["side"])
    adjusted_size      = position_size * (1.0 - correlation_factor)

    log("🛡️  AMYGDALA: APPROVED. Size=$#{adjusted_size.round(2)} Leverage=#{leverage}x R:R=#{rr_ratio.round(2)}")

    @ns.broadcast(:approved_order, {
      plan:         plan,
      size_usd:     adjusted_size,
      leverage:     leverage,
      risk_pct:     kelly_fraction * 100,
      rr_ratio:     rr_ratio
    })
  end

  def trade_closed(pnl_usd:)
    @session_pnl += pnl_usd
    drawdown_pct   = -@session_pnl / @equity

    if drawdown_pct >= MAX_DAILY_DRAWDOWN
      @desk_open = false
      log("🔴 AMYGDALA: Daily drawdown #{(drawdown_pct * 100).round(2)}% breached. DESK CLOSED for session.")
      @ns.broadcast(:desk_closed, reason: "daily_drawdown_limit")
    end
  end

  private

  def correlation_penalty(side)
    # Stub: returns 0.0–0.5 based on open position correlation
    # In prod: fetch open positions, compute 30-day rolling correlation
    # matrix between BTC/ETH/SOL. If net delta exposure is already high,
    # reduce new position size accordingly.
    0.0
  end

  def log(msg) = puts("[#{Time.now.strftime('%H:%M:%S')}] #{msg}")
end
```

---

## Execution

### Motor Cortex — Execution & Binance Client

HMAC-signed Binance FAPI REST client + async iceberg execution. Splits large orders into tranches to avoid book impact and HFT detection.

### app/clients/binance_futures_client.rb

```ruby
require "faraday"
require "faraday/retry"
require "openssl"

class BinanceFuturesClient
  def initialize(api_key:, secret_key:, recv_window: 5000)
    @api_key = api_key
    @secret  = secret_key
    @recv    = recv_window
    @conn    = Faraday.new(BINANCE_REST) do |f|
      f.request :retry, max: 3, interval: 0.5, retry_statuses: [429]
      f.adapter Faraday.default_adapter
    end
  end

  def get_price(symbol)   = signed_get("/fapi/v1/ticker/price", symbol:)["price"].to_f
  def get_funding_rate(s) = signed_get("/fapi/v1/fundingRate", symbol: s, limit: 1).first
  def get_open_interest(s)= signed_get("/fapi/v1/openInterest", symbol: s)

  def set_leverage(symbol:, leverage:)
    signed_post("/fapi/v1/leverage", symbol:, leverage:)
  end

  def place_limit_order(symbol:, side:, size_usd:, price:)
    quantity = (size_usd / price).round(3)
    signed_post("/fapi/v1/order",
      symbol:           symbol,
      side:             side.upcase,
      type:             "LIMIT",
      price:            price.round(2),
      quantity:         quantity,
      timeInForce:      "GTC",
      reduceOnly:       false
    )
  end

  def place_stop_order(symbol:, side:, quantity:, stop_price:)
    signed_post("/fapi/v1/order",
      symbol:           symbol,
      side:             side.upcase,
      type:             "STOP_MARKET",
      stopPrice:        stop_price.round(2),
      quantity:         quantity,
      closePosition:    false
    )
  end

  private

  def signed_get(path, params = {})
    p = timestamped(params)
    p[:signature] = sign(p)
    resp = @conn.get(path, p, auth_header)
    Oj.load(resp.body)
  end

  def signed_post(path, params = {})
    p = timestamped(params)
    p[:signature] = sign(p)
    resp = @conn.post(path, URI.encode_www_form(p), auth_header)
    Oj.load(resp.body)
  end

  def timestamped(p) = p.merge(recvWindow: @recv, timestamp: (Time.now.to_f * 1000).to_i)
  def auth_header    = { "X-MBX-APIKEY" => @api_key }
  def sign(params)
    query = URI.encode_www_form(params.sort.to_h)
    OpenSSL::HMAC.hexdigest("SHA256", @secret, query)
  end
end
```

### app/lobes/motor_cortex.rb

```ruby
class MotorCortex
  TRANCHE_COUNT = 4
  TRANCHE_DELAY = 15  # seconds between tranches

  def initialize(nervous_system:, binance:)
    @ns      = nervous_system
    @binance = binance
    @ns.subscribe(self, on: :approved_order)
  end

  def approved_order(order_data)
    plan     = order_data[:plan]
    symbol   = plan["symbol"] || "BTCUSDT"
    side     = plan["side"]        # "LONG" or "SHORT"
    total    = order_data[:size_usd]
    leverage = order_data[:leverage]
    stop_px  = plan["invalidation_price"]
    entry_lo = plan["entry_zone"]["low"]
    target1  = plan["targets"][0]

    # Set leverage first
    @binance.set_leverage(symbol:, leverage:)

    Async do |task|
      tranche_size = total / TRANCHE_COUNT
      total_qty    = 0.0

      TRANCHE_COUNT.times do |i|
        task.async do
          # Wait for price to enter entry zone
          wait_for_entry_zone(symbol, entry_lo, plan["entry_zone"]["high"])

          current_price = @binance.get_price(symbol)
          result = @binance.place_limit_order(
            symbol:   symbol,
            side:     side == "LONG" ? "BUY" : "SELL",
            size_usd: tranche_size,
            price:    current_price
          )

          qty = result["executedQty"].to_f
          total_qty += qty
          puts "⚡ Tranche #{i+1}/#{TRANCHE_COUNT} filled: #{qty} @ #{current_price}"

          sleep TRANCHE_DELAY
        end
      end

      # Place stop-loss once all tranches are done
      task.async do
        sleep TRANCHE_COUNT * TRANCHE_DELAY + 5
        stop_side = side == "LONG" ? "SELL" : "BUY"
        @binance.place_stop_order(
          symbol:     symbol,
          side:       stop_side,
          quantity:   total_qty.round(3),
          stop_price: stop_px
        )
        puts "🛑 Stop-loss placed at #{stop_px}"
        @ns.broadcast(:execution_complete, symbol:, qty: total_qty, stop: stop_px)
      end
    end
  end

  private

  def wait_for_entry_zone(symbol, lo, hi)
    loop do
      price = @binance.get_price(symbol)
      break if price.between?(lo, hi)
      sleep 0.5
    end
  end
end
```

---

## Daily Lifecycle

### Daily Lifecycle & Boot Sequence

Nemesis runs a structured daily routine: pre-market macro analysis, intraday execution, post-market post-mortem, and a weekend "dream state" for self-improvement.

### Daily Flow

1. **08:00 UTC — Pre-Market Macro Scan**
   - Scrape economic calendar (CPI, FOMC, Powell). If high-impact event within 30 mins, CRO halves all position sizes or halts trading entirely. Feed overnight news into Hippocampus as background context.

2. **09:00–20:00 UTC — Intraday Execution**
   - SensoryCortex streams Binance WS. Alpha Wave Loop pulses every 60s. PrefrontalCortex evaluates tape signals, recalls episodic memories, generates Trade Plans. CRO gates all plans before MotorCortex executes.

3. **21:00 UTC — Nightly Post-Mortem**
   - TradeJournalist fetches today's closed trades. LLM reviews PM's original thesis vs actual outcome, identifies cognitive biases (FOMO, revenge trading, moving stops). Generates 2 new "Core Rules" appended to PM's system prompt for tomorrow.

4. **Weekend — Dream State**
   - Monte Carlo simulation on week's trades to recalculate Kelly fraction. LLM reviews all losing trades, outputs new risk rules or prompt constraints. "Lessons learned" stored as new Qdrant embeddings tagged as "Core Beliefs".

### boot_nemesis.rb

```ruby
require_relative "config/nemesis"
require_relative "app/lobes/hippocampus"
require_relative "app/lobes/sensory_cortex"
require_relative "app/lobes/prefrontal_cortex"
require_relative "app/lobes/amygdala"
require_relative "app/lobes/motor_cortex"
require_relative "app/clients/binance_futures_client"
require "wisper"
require "concurrent"

puts "🧠 Booting Nemesis Cognitive Architecture v1.0..."
puts "   Model  : #{REASONING_MODEL} via Ollama Cloud"
puts "   Target : #{BINANCE_REST}"

# ── Wiring ────────────────────────────────────────────────────
class NervousSystem
  include Wisper::Publisher
end

nervous_system = NervousSystem.new
binance        = BinanceFuturesClient.new(
  api_key:    ENV["BINANCE_KEY"],
  secret_key: ENV["BINANCE_SECRET"]
)

hippocampus = Hippocampus.new
sensory     = SensoryCortex.new(nervous_system)
cortex      = PrefrontalCortex.new(nervous_system:, hippocampus:)
amygdala    = Amygdala.new(nervous_system:, equity: 10_000)
motor       = MotorCortex.new(nervous_system:, binance:)

# ── Alpha Wave Loop (background introspection) ─────────────────
alpha_wave = Concurrent::TimerTask.new(execution_interval: 60) do
  funding     = binance.get_funding_rate("BTCUSDT")
  oi          = binance.get_open_interest("BTCUSDT")
  nervous_system.broadcast(:alpha_wave_pulse, funding_rates: funding, open_interest: oi)
end

# ── Launch ─────────────────────────────────────────────────────
alpha_wave.execute
puts "🌊 Alpha Wave Loop started (60s interval)"

sensory.start(symbol: "btcusdt")
puts "👁️  SensoryCortex online — streaming BTCUSDT tape"
puts "🧠 Nemesis is awake."

sleep  # Keep main thread alive
```

### app/jobs/nightly_post_mortem.rb

```ruby
class NightlyPostMortem
  def initialize(hippocampus:, config_path:)
    @memory      = hippocampus
    @config_path = config_path
    @llm         = RubyLLM.chat(model: REASONING_MODEL, provider: :ollama)
  end

  def run
    losses = @memory.recent_losses(days: 1)
    return puts("📖 Post-mortem: No losses today. Great session.") if losses.empty?

    journal = losses.map { |p| p["payload"]["text"] }.join("

")

    prompt = <<~P
      Review today's losing trades:
      #{journal}

      Identify cognitive biases (FOMO, revenge trading, moving stops, exiting early).
      Suggest 2 concrete new rules for the Portfolio Manager's system prompt.

      JSON: {
        "biases": ["string"],
        "new_rules": ["Rule 1: ...", "Rule 2: ..."],
        "summary": "string"
      }
    P

    review = Oj.load(@llm.ask(prompt, response_format: { type: "json_object" }).content)

    # Append new rules to PM config
    File.open(@config_path, "a") do |f|
      review["new_rules"].each { |r| f.puts("# #{Date.today}: #{r}") }
    end

    puts "📖 Post-mortem complete: #{review['summary']}"
    puts "📋 New rules: #{review['new_rules'].join(' | ')}"
  end
end
```

---

## Gem Stack

### Complete Gem Stack

Every gem used by Nemesis, organised by brain lobe function.

| Gem | Version | Lobe / Role | Purpose |
|---|---|---|---|
| `ruby_llm` | `~> 1.2` | Prefrontal Cortex | Unified Ollama Cloud interface. JSON mode, tool calling, streaming, embed support. |
| `langchainrb` | `~> 0.8` | Prefrontal Cortex | ReAct agent loop, vectorstore abstraction, document loaders for RAG ingestion. |
| `oj` | `~> 3.16` | Prefrontal Cortex | Fast JSON parsing for LLM structured output — 10–20× faster than stdlib JSON. |
| `wisper` | `~> 2.0` | NervousSystem | Pub/Sub event bus. Decouples lobes so each can be independently tested and replaced. |
| `concurrent-ruby` | `~> 1.2` | NervousSystem | Thread-safe data structures, TimerTask for the 60s alpha wave heartbeat loop. |
| `async` | `~> 2.8` | Motor Cortex | Non-blocking I/O for async TWAP/iceberg execution and WebSocket connections. |
| `async-websocket` | `~> 0.25` | SensoryCortex | Streams aggTrade, depth20, forceOrder from Binance FAPI WebSocket endpoint. |
| `faraday` | `~> 2.9` | Motor Cortex | HTTP client for all Binance REST API calls (orders, prices, funding rates, OI). |
| `faraday-retry` | `~> 2.2` | Motor Cortex | Auto-retry with backoff on 429 rate limit responses. Binance limit: 2400 req/min. |
| `qdrant-ruby` | `~> 1.2` | Hippocampus | Vector database client. Stores episodic trade memories as embeddings, runs cosine recall. |
| `redis` | `~> 5.0` | Hippocampus | Short-term working memory: current position state, live P&L, session flags (desk open/closed). |
| `pg` | `~> 1.5` | Hippocampus | PostgreSQL for long-term trade logs. Use pgvector extension to combine relational + RAG. |
| `numo-narray` | `~> 0.9` | SensoryCortex | N-dimensional arrays for order book math, CVD calculations, volume profiling. |
| `talib-ruby` | latest | SensoryCortex | ATR, RSI, MACD, Bollinger Bands — raw signal inputs for the reasoning layer. |
| `descriptive_statistics` | latest | Amygdala | VaR, standard deviation, correlation for CRO risk calculations. |
| `matrix` | stdlib | Amygdala | Cross-asset correlation matrix for position sizing penalty calculations. |
| `prometheus-client` | latest | Observability | Metrics: intent accuracy rate, tool success, average slippage, P&L, risk breaches. |
| `sentry-ruby` | latest | Observability | Exception tracking. Every unhandled error in any lobe is captured with full context. |

> **Latency note:** Ollama Cloud llama3:70b averages 800ms–2s per reasoning call. For sub-second strategies, precompute signals with talib-ruby and use the LLM only for plan generation and macro bias — not tick-by-tick decisions.

### Recommended Build Order

1. **Ollama Cloud + ruby_llm basic ping**
   - Verify API key, JSON mode, and embedding with nomic-embed-text.

2. **BinanceFuturesClient on Testnet**
   - Implement `get_price`, `place_limit_order`, `place_stop_order`. Verify HMAC signing.

3. **Hippocampus (Qdrant)**
   - `store_episode` + `recall`. Seed with 20 synthetic trade episodes to verify cosine search.

4. **NervousSystem + SensoryCortex**
   - Wire WebSocket → CVD → wisper broadcast. Log every absorption signal detected.

5. **PrefrontalCortex + Amygdala**
   - Full reasoning loop: tape signal → Trade Plan → CRO gate → `approved_order` event. Paper-trade only.

6. **MotorCortex iceberg execution**
   - Enable live Testnet execution. Run 2–4 weeks, log every decision.

7. **Nightly Post-Mortem cron**
   - Run TradeJournalist every night. Verify new rules are being generated and appended.

8. **Prometheus + Sentry**
   - Add observability before any live capital. You need full decision logs to debug LLM behaviour.

---

*Generated from Nemesis Cognitive Trading Brain v1.0 — Ruby + Ollama Cloud*

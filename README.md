# Nemesis: Cognitive Trading Agent for Crypto Futures

A professional-grade, biologically-inspired autonomous trading system built with Ruby and Ollama Cloud APIs. Nemesis implements a cognitive architecture that mimics the structure of a human brain to make disciplined, risk-aware trading decisions on cryptocurrency futures markets.

## 🧠 Architecture Overview

Nemesis is designed as a **continuous cognitive system** rather than a simple reactive script. It maps brain regions to specialized trading desk roles:

| Brain Region | Desk Role | Function |
|--------------|-----------|----------|
| **Prefrontal Cortex** | Portfolio Manager (PM) | LLM-powered reasoning agent that synthesizes market data into structured trade plans with entry zones, invalidation points, and targets |
| **Amygdala** | Chief Risk Officer (CRO) | Deterministic risk gate that enforces Kelly Criterion sizing, daily drawdown limits, and correlation checks |
| **Hippocampus** | Trade Journal / Memory | Vector database (Qdrant) storing episodic memories of past trades for contextual recall |
| **Sensory Cortex** | Tape Reader | Real-time WebSocket consumer analyzing order flow, CVD, and liquidations |
| **Motor Cortex** | Execution Trader | Executes approved orders using TWAP/iceberg algorithms to minimize slippage |
| **Nervous System** | Event Bus | Pub/sub architecture decoupling all components via Wisper |

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3+
- Ollama Cloud API key (or local Ollama instance)
- Binance Futures API credentials (optional for paper mode)

### Installation

```bash
# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env with your API keys and preferences
```

### Configuration

Create a `.env` file in the root directory:

```bash
# Ollama Configuration
OLLAMA_API_KEY=your_api_key_here
OLLAMA_URL=https://ollama.com/v1

# Model Selection
NEMESIS_REASONING_MODEL=gemma4:31b
NEMESIS_EMBED_MODEL=nomic-embed-text

# Trading Configuration
NEMESIS_SYMBOL=btcusdt
NEMESIS_EQUITY=10000
NEMESIS_PAPER_MODE=true
NEMESIS_LLM_ENABLED=false

# Optional: Qdrant for persistent memory
QDRANT_URL=http://localhost:6333
QDRANT_API_KEY=

# Binance (leave as "paper" for testnet)
BINANCE_KEY=paper
BINANCE_SECRET=paper
BINANCE_REST=https://fapi.binance.com
BINANCE_WS=wss://fstream.binance.com

# Logging
VERBOSE_LOGS=false
```

### Running Nemesis

```bash
# Boot the cognitive architecture
ruby boot_nemesis.rb
```

The system will start:
1. **Alpha Wave Loop** - Background introspection pulse (60s interval)
2. **Sensory Cortex** - Real-time market data streaming
3. **All Lobes** - Prefrontal Cortex, Amygdala, Motor Cortex, Hippocampus

Press `Ctrl+C` for graceful shutdown.

## 📚 Documentation

- [Architecture Deep Dive](docs/nemesis_brain.md)
- [Model-to-Lobe Mapping](docs/Model-to-Lobe.md)
- [Research & Implementation Guide](docs/research.md)

## 🏗️ System Components

### Nervous System (Event Bus)

The central nervous system uses the `wisper` gem to implement a pub/sub pattern, allowing brain lobes to communicate without tight coupling:

```ruby
class NervousSystem
  include Wisper::Publisher
  public :broadcast
end
```

Events broadcast include:
- `:tape_signal_detected` - From Sensory Cortex
- `:trade_plan_generated` - From Prefrontal Cortex
- `:approved_order` - From Amygdala
- `:alpha_wave_pulse` - Background macro updates

### Sensory Cortex (Tape Reader)

Processes real-time Binance Futures WebSocket streams:
- Aggregated trades (`@aggTrade`)
- Order book depth (`@depth20`)
- Liquidations (`@forceOrder`)

Detects **absorption patterns** where high delta volume fails to move price, indicating limit order absorption.

### Prefrontal Cortex (Portfolio Manager)

LLM-powered reasoning engine that:
1. Receives tape signals from Sensory Cortex
2. Retrieves relevant memories from Hippocampus
3. Generates structured trade plans in JSON format
4. Grades setups (A/B/C) based on confluence

Only "A" grade setups are passed to the Amygdala for risk approval.

### Amygdala (Chief Risk Officer)

Deterministic risk management layer that:
- Enforces minimum R:R ratio (default 2.0)
- Calculates position size using Kelly Criterion
- Applies correlation penalties for concentrated portfolios
- Implements daily drawdown kill switch (default 3%)

### Hippocampus (Episodic Memory)

Stores and retrieves trade experiences using vector embeddings:
- **Qdrant** for production persistence
- **In-memory fallback** for development/paper mode
- Embeddings generated via Ollama Cloud API
- Recall based on semantic similarity to current market context

### Motor Cortex (Execution Trader)

Currently operates in **analysis-only mode**, logging intended orders without execution. Future implementation will include:
- TWAP/VWAP execution algorithms
- Iceberg order splitting
- Limit order placement at entry zones

## 🧪 Testing

```bash
# Run the test suite
bundle exec rspec

# Run specific spec files
bundle exec rspec spec/nervous_system_spec.rb
bundle exec rspec spec/amygdala_spec.rb
bundle exec rspec spec/hippocampus_spec.rb
```

Tests verify:
- Event broadcasting between lobes
- Risk gating logic in Amygdala
- Memory storage/recall in Hippocampus

## 🔒 Safety Features

### Paper Mode
Default configuration runs in paper mode where:
- No real orders are placed
- Simulated prices used if API unavailable
- All trade plans logged but not executed

### Risk Limits
Hard-coded maximums prevent catastrophic losses:
- Max risk per trade: 1% of equity
- Max daily drawdown: 3% of equity
- Max leverage: 20x
- Minimum R:R ratio: 2.0

### Graceful Shutdown
Trap handler ensures clean termination:
- Alpha wave timer stopped
- WebSocket connections closed
- State saved (when Qdrant enabled)

## 🛠️ Development

### Adding New Lobes

1. Create a new Ruby class in `app/lobes/`
2. Subscribe to relevant events in `initialize`
3. Implement event handler methods matching broadcast names
4. Add require path to `lib/nemesis_brain.rb`

Example:
```ruby
class NewLobe
  def initialize(nervous_system:)
    @ns = nervous_system
    @ns.subscribe(self)
  end

  def tape_signal_detected(signal)
    # Handle signal
  end
end
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMESIS_REASONING_MODEL` | `gemma4:31b` | LLM model for trade planning |
| `NEMESIS_EMBED_MODEL` | `gemma4:31b` | Model for memory embeddings |
| `NEMESIS_SYMBOL` | `btcusdt` | Trading pair |
| `NEMESIS_EQUITY` | `10000` | Account size in USD |
| `NEMESIS_PAPER_MODE` | `false` | Disable live execution |
| `NEMESIS_LLM_ENABLED` | `false` | Enable/disable LLM calls |
| `VERBOSE_LOGS` | `false` | Detailed logging output |

## 📈 Performance Considerations

- **WebSocket Reconnection**: Automatic retry with exponential backoff
- **Rate Limiting**: Binance API calls respect 2400 req/min limit
- **Memory Efficiency**: Numo::NArray for order book calculations
- **Async Processing**: Non-blocking I/O for market data ingestion

## 🚧 Roadmap

- [ ] Live order execution with TWAP algorithms
- [ ] Multi-symbol correlation tracking
- [ ] ATR-based dynamic position sizing
- [ ] Nightly post-mortem automation
- [ ] Monte Carlo simulation for Kelly optimization
- [ ] Economic calendar integration for macro events
- [ ] Prometheus metrics export
- [ ] Docker containerization

## ⚠️ Disclaimer

**This software is for educational and research purposes only.** Cryptocurrency futures trading involves substantial risk of loss and is not suitable for every investor. The use of this software does not guarantee profits. Past performance is not indicative of future results.

Always test thoroughly on Binance Testnet before considering live deployment. Never trade with capital you cannot afford to lose.

## 📄 License

MIT License - See LICENSE file for details.

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines before submitting PRs.

---

Built with 💎 Ruby and 🦙 Ollama Cloud
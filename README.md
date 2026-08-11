# QuantDesk: Autonomous Trading Desk for Crypto Futures

[![CI](https://github.com/shubhamtaywade82/nemesis_brain/actions/workflows/ci.yml/badge.svg)](https://github.com/shubhamtaywade82/nemesis_brain/actions/workflows/ci.yml)
[![Security](https://github.com/shubhamtaywade82/nemesis_brain/actions/workflows/security.yml/badge.svg)](https://github.com/shubhamtaywade82/nemesis_brain/actions/workflows/security.yml)

A professional-grade autonomous trading system built with Ruby and Ollama, organized as a set of specialized trading-desk roles that communicate over a shared event bus. QuantDesk makes disciplined, risk-aware trading decisions on cryptocurrency futures markets. LLM reasoning is powered by the [`ollama-client`](https://github.com/shubhamtaywade82/ollama-client) gem, which gives structured, schema-validated JSON output straight from `chat`/`generate` calls — no manual JSON parsing or repair logic required.

## 📊 Architecture Overview

QuantDesk is designed as a **continuous, event-driven system** rather than a simple reactive script. Each desk owns one narrow responsibility and communicates only through the event bus:

| Desk | Class | Function |
|------|-------|----------|
| **Portfolio Manager** | `PortfolioManager` | LLM-powered reasoning agent that synthesizes market data into structured trade plans with entry zones, invalidation points, and targets |
| **Risk Manager** | `RiskManager` | Deterministic risk gate that enforces Kelly Criterion sizing, daily drawdown limits, and correlation checks |
| **Trade Journal** | `TradeJournal` | Vector database (Qdrant) storing trade history for contextual recall |
| **Tape Reader** | `TapeReader` | Real-time WebSocket consumer analyzing order flow, CVD, and liquidations |
| **Execution Trader** | `ExecutionTrader` | Executes approved orders using TWAP/iceberg algorithms to minimize slippage |
| **Event Bus** | `EventBus` | Pub/sub architecture decoupling all desks via Wisper |

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3+
- A local Ollama instance, or an Ollama Cloud API key
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
# Ollama Configuration (native API, via the ollama-client gem)
# Local Ollama needs no API key. For Ollama Cloud, set OLLAMA_BASE_URL to
# https://ollama.com and OLLAMA_API_KEY (or a comma-separated OLLAMA_API_KEYS pool).
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_API_KEY=

# Model Selection
QUANTDESK_REASONING_MODEL=gemma4:31b
QUANTDESK_EMBED_MODEL=nomic-embed-text

# Trading Configuration
QUANTDESK_SYMBOL=btcusdt
QUANTDESK_EQUITY=10000
QUANTDESK_PAPER_MODE=true
QUANTDESK_LLM_ENABLED=false

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

### Running QuantDesk

```bash
# Boot the trading desk
ruby boot_nemesis.rb
```

The system will start:
1. **Macro Pulse** - Background funding/open-interest pulse (60s interval)
2. **Tape Reader** - Real-time market data streaming
3. **All Desks** - Portfolio Manager, Risk Manager, Execution Trader, Trade Journal

Press `Ctrl+C` for graceful shutdown.

## 📚 Documentation

- [Architecture Deep Dive](docs/quantdesk_architecture.md)
- [Model-to-Desk Mapping](docs/Model-to-Desk.md)
- [Research & Implementation Guide](docs/research.md)

## 🏗️ System Components

### Event Bus

The event bus uses the `wisper` gem to implement a pub/sub pattern, allowing desks to communicate without tight coupling:

```ruby
class EventBus
  include Wisper::Publisher
  public :broadcast
end
```

Events broadcast include:
- `:tape_signal_detected` - From Tape Reader
- `:trade_plan_generated` - From Portfolio Manager
- `:approved_order` - From Risk Manager
- `:macro_snapshot_updated` - Background macro updates

### Tape Reader

Processes real-time Binance Futures WebSocket streams:
- Aggregated trades (`@aggTrade`)
- Order book depth (`@depth20`)
- Liquidations (`@forceOrder`)

Detects **absorption patterns** where high delta volume fails to move price, indicating limit order absorption.

### Portfolio Manager

LLM-powered reasoning engine that:
1. Receives tape signals from the Tape Reader
2. Retrieves similar past trades from the Trade Journal
3. Generates structured trade plans in JSON format
4. Grades setups (A/B/C) based on confluence

Only "A" grade setups are passed to the Risk Manager for approval.

### Risk Manager

Deterministic risk management layer that:
- Enforces minimum R:R ratio (default 2.0)
- Calculates position size using Kelly Criterion
- Applies correlation penalties for concentrated portfolios
- Implements daily drawdown kill switch (default 3%)

### Trade Journal

Stores and retrieves trade history using vector embeddings:
- **Qdrant** for production persistence
- **In-memory fallback** for development/paper mode
- Embeddings generated via `ollama-client` (local or cloud, depending on `OLLAMA_BASE_URL`)
- Recall based on semantic similarity to current market context

### Execution Trader

Currently operates in **analysis-only mode**, logging intended orders without execution. Future implementation will include:
- TWAP/VWAP execution algorithms
- Iceberg order splitting
- Limit order placement at entry zones

## 🧪 Testing & CI

```bash
# Run the test suite
bundle exec rspec

# Run specific spec files
bundle exec rspec spec/event_bus_spec.rb
bundle exec rspec spec/risk_manager_spec.rb
bundle exec rspec spec/trade_journal_spec.rb
bundle exec rspec spec/portfolio_manager_spec.rb
bundle exec rspec spec/binance_futures_client_spec.rb

# Lint
bundle exec rubocop
```

Tests verify:
- Event broadcasting between desks
- Risk gating logic in the Risk Manager
- Trade storage/recall in the Trade Journal
- Ollama client wiring in the Portfolio Manager (via an injected fake client)
- The `TradeDisabledError` safety invariant on `BinanceFuturesClient`

Every push and pull request against `main` runs two GitHub Actions workflows:
- **[CI](.github/workflows/ci.yml)** — `bundle exec rspec` on Ruby 3.1 and 3.3, `bundle exec
  rubocop`, and a boot smoke test that boots QuantDesk in paper mode and confirms it stays
  up instead of crashing.
- **[Security](.github/workflows/security.yml)** — `bundler-audit` against the gem lockfile
  and GitHub CodeQL static analysis for Ruby, both also on a weekly schedule so newly
  disclosed CVEs get caught even without new commits.

Dependabot (`.github/dependabot.yml`) opens weekly PRs for outdated gems and Actions.

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
- Macro pulse timer stopped
- WebSocket connections closed
- State saved (when Qdrant enabled)

## 🛠️ Development

### Adding New Desks

1. Create a new Ruby class in `app/desks/`
2. Subscribe to relevant events in `initialize`
3. Implement event handler methods matching broadcast names
4. Add require path to `lib/nemesis.rb`

Example:
```ruby
class NewDesk
  def initialize(event_bus:)
    @events = event_bus
    @events.subscribe(self)
  end

  def tape_signal_detected(signal)
    # Handle signal
  end
end
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QUANTDESK_REASONING_MODEL` | `gemma4:31b` | LLM model for trade planning |
| `QUANTDESK_EMBED_MODEL` | `nomic-embed-text` | Model for memory embeddings |
| `QUANTDESK_SYMBOL` | `btcusdt` | Trading pair |
| `QUANTDESK_EQUITY` | `10000` | Account size in USD |
| `QUANTDESK_PAPER_MODE` | `false` | Disable live execution |
| `QUANTDESK_LLM_ENABLED` | `false` | Enable/disable LLM calls |
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
- [ ] Nightly trade review automation
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

Built with 💎 Ruby and 🦙 Ollama
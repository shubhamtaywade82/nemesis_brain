# Model-to-Desk Mapping

Nemesis maps Ollama models to trading desks by **runtime role**, not by hardcoded coupling. Model names are configuration (`NEMESIS_REASONING_MODEL`, `NEMESIS_EMBED_MODEL`) so you can swap providers without changing desk code.

## Primary Mapping

| Desk | Class | Role | Ollama Model (default) | Mode | Function |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Portfolio Manager** | `PortfolioManager` | Portfolio Manager | `llama3:70b` | Chat + JSON | Trade thesis, entry zone, invalidation, targets, setup grade |
| **Trade Journal** | `TradeJournal` | Trade Journal / RAG | `nomic-embed-text` | Embeddings | Trade history store + cosine recall |
| **Risk Manager** | `RiskManager` | Chief Risk Officer | *(none — deterministic)* | Rules engine | Kelly sizing, R:R gate, daily drawdown kill switch |
| **Tape Reader** | `TapeReader` | Tape Reader | *(none — deterministic)* | WebSocket math | CVD, absorption, liquidation events |
| **Execution Trader** | `ExecutionTrader` | Execution Trader | *(none — deterministic)* | REST + async | Iceberg/TWAP-style limit entry, stop placement |
| **Event Bus** | `EventBus` | Event Bus | *(none)* | Wisper pub/sub | Decouples all desks |

## Secondary / Scheduled Agents

| Agent | Job Class | Ollama Model | Schedule | Function |
| :--- | :--- | :--- | :--- | :--- |
| **Trade Reviewer** | `NightlyTradeReview` | `llama3:70b` | 21:00 UTC daily | Bias detection, prompt rule updates |
| **Macro Analyst** | `PortfolioManager#macro_snapshot_updated` | `llama3:70b` | Every 60s (Macro Pulse) | Funding rate + open interest bias |
| **Dream State** | *(planned)* | `llama3:70b` | Weekends | Monte Carlo + losing-trade consolidation |

## Reflexes vs Reasoning

| Layer | Desks | LLM? | Latency Target |
| :--- | :--- | :--- | :--- |
| **Reflexes (deterministic)** | Risk Manager, Tape Reader, Execution Trader | No | Sub-second to low seconds |
| **Reasoning (LLM-backed)** | Portfolio Manager, Trade Journal, NightlyTradeReview | Yes | ~800ms–2s per call |

## Configuration

```bash
# .env
NEMESIS_REASONING_MODEL=llama3:70b      # Portfolio Manager + Trade Review
NEMESIS_EMBED_MODEL=nomic-embed-text   # Trade Journal embeddings
OLLAMA_BASE_URL=https://ollama.com
OLLAMA_API_KEY=your_key
```

When `OLLAMA_API_KEY` is unset and `OLLAMA_BASE_URL` points at a local Ollama instance, no key is needed at all. When `NEMESIS_LLM_ENABLED` is left off, the Portfolio Manager and Trade Review job run in **paper mode** with deterministic stubs. The Risk Manager and Execution Trader remain fully active for local integration testing.

## Prompt Versioning

Versioned prompts live under `config/prompts/` (future). Nightly trade review appends immutable rules to `config/pm_rules.txt` — never edit deployed prompt versions in place; add a new dated rule line instead.

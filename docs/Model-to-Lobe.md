# Model-to-Lobe Mapping

Nemesis maps Ollama models to brain lobes by **runtime role**, not by hardcoded coupling. Model names are configuration (`NEMESIS_REASONING_MODEL`, `NEMESIS_EMBED_MODEL`) so you can swap providers without changing lobe code.

## Primary Mapping

| Brain Region | Nemesis Lobe | Desk Role | Ollama Model (default) | Mode | Function |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Prefrontal Cortex** | `PrefrontalCortex` | Portfolio Manager | `llama3:70b` | Chat + JSON | Trade thesis, entry zone, invalidation, targets, setup grade |
| **Hippocampus** | `Hippocampus` | Trade Journal / RAG | `nomic-embed-text` | Embeddings | Episodic memory store + cosine recall |
| **Amygdala** | `Amygdala` | Chief Risk Officer | *(none — deterministic)* | Rules engine | Kelly sizing, R:R gate, daily drawdown kill switch |
| **Sensory Cortex** | `SensoryCortex` | Tape Reader | *(none — deterministic)* | WebSocket math | CVD, absorption, liquidation events |
| **Motor Cortex** | `MotorCortex` | Execution Trader | *(none — deterministic)* | REST + async | Iceberg/TWAP-style limit entry, stop placement |
| **Nervous System** | `NervousSystem` | Event Bus | *(none)* | Wisper pub/sub | Decouples all lobes |

## Secondary / Scheduled Agents

| Agent | Job Class | Ollama Model | Schedule | Function |
| :--- | :--- | :--- | :--- | :--- |
| **Trade Journalist** | `NightlyPostMortem` | `llama3:70b` | 21:00 UTC daily | Bias detection, prompt rule updates |
| **Macro Analyst** | `PrefrontalCortex#alpha_wave_pulse` | `llama3:70b` | Every 60s (Alpha Wave) | Funding rate + open interest bias |
| **Dream State** | *(planned)* | `llama3:70b` | Weekends | Monte Carlo + losing-trade consolidation |

## System 1 vs System 2

| System | Lobes | LLM? | Latency Target |
| :--- | :--- | :--- | :--- |
| **System 1 (Reflexes)** | Amygdala, Sensory Cortex, Motor Cortex | No | Sub-second to low seconds |
| **System 2 (Reasoning)** | Prefrontal Cortex, Hippocampus, NightlyPostMortem | Yes | ~800ms–2s per call |

## Configuration

```bash
# .env
NEMESIS_REASONING_MODEL=llama3:70b      # Prefrontal Cortex + Post-Mortem
NEMESIS_EMBED_MODEL=nomic-embed-text   # Hippocampus embeddings
OLLAMA_URL=https://ollama.com/v1
OLLAMA_API_KEY=your_key
```

When `OLLAMA_API_KEY` is unset, Prefrontal Cortex and Post-Mortem run in **paper mode** with deterministic stubs. Amygdala and execution remain fully active for local integration testing.

## Prompt Versioning

Versioned prompts live under `config/prompts/` (future). Nightly post-mortem appends immutable rules to `config/pm_rules.txt` — never edit deployed prompt versions in place; add a new dated rule line instead.

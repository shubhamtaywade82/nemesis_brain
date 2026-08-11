# AGENTS.md

Instructions for any coding agent (Claude, Qwen, Codex, etc.) working in this repository.

## Project quick facts

- Ruby trading-desk app. Entry point: `boot_nemesis.rb` → `lib/nemesis.rb` → `QuantDesk.boot`.
- Desks live in `app/desks/` (`PortfolioManager`, `RiskManager`, `TradeJournal`, `TapeReader`,
  `ExecutionTrader`), communicating over `EventBus` (`app/event_bus.rb`) via Wisper pub/sub.
- Config and shared constants: `config/nemesis.rb` (module `QuantDesk`). Env vars use the
  `QUANTDESK_*` prefix (e.g. `QUANTDESK_SYMBOL`, `QUANTDESK_LLM_ENABLED`) — see `.env.example`
  for the full list. If you add a new config constant, keep the prefix consistent across
  `config/nemesis.rb`, `.env.example`, and `README.md` in the same change; a mismatched
  prefix silently falls back to the default instead of erroring, so it's easy to miss.
- Tests: `spec/`, run with `bundle exec rspec`. No linter is configured yet.
- **Safety invariant**: `ExecutionTrader`/`BinanceFuturesClient` never place real orders —
  order placement methods raise `TradeDisabledError` unconditionally. Do not wire up live
  execution without the user explicitly asking for it.

## Agent Workflow Rules

- When asked to implement, fix, or add anything, ALWAYS modify the actual files with the
  editor tool. Never reply with only explanations or chat-only code snippets.
- After editing, run the relevant checks:
  - `bundle exec rspec` (full suite, or `bundle exec rspec spec/<file>_spec.rb` for a
    targeted run)
  - `timeout 10 ruby boot_nemesis.rb` as a smoke test when boot wiring (`lib/nemesis.rb`,
    `app/desks/*`, `config/nemesis.rb`) changes. The process runs forever until interrupted,
    so always wrap it in `timeout` rather than running it directly — an unwrapped run blocks
    the agent's only shell. The startup banner must appear before the timeout fires; **exit
    code 124 (killed by timeout) is expected success**. A crash, or no banner before the
    timeout, means something is broken.
- Then commit and push:
  ```bash
  git add -A
  git commit -m "<concise message>"
  git push -u origin HEAD
  ```
- If the editor tool fails, write the file via a bash heredoc instead:
  ```bash
  cat > path/to/file.rb <<'EOF'
  <full file contents>
  EOF
  ```
- Always finish by showing `git status --short` and `git log --oneline -1` as proof the
  change actually landed. If any tool fails, state exactly which tool failed and the error
  — don't silently fall back to a text-only answer.
- Prefer small, focused tasks per session (one feature/fix at a time) over broad
  "review and improve" requests, which are more likely to end in discussion instead of
  a diff.

## Git & session rules

- Before pushing, run `git remote -v`. If `origin` is missing, restore it to this repo's
  plain HTTPS URL (`https://github.com/shubhamtaywade82/nemesis_brain.git`) and rely on
  the environment's pre-configured git credentials — do not embed a token or password
  directly in the remote URL. A URL-embedded credential persists in `.git/config` and gets
  echoed back by `git remote -v`, which is itself a secret leak (see the secrets rule
  below). If your environment truly has no credential helper and a token is the only way
  to auth, set it for a single push via `-c http.extraheader`, not by editing the remote
  URL, and never print the header value.
- Work on the current branch. Do not create a new branch on a follow-up request unless
  explicitly asked to. If you do create one, use `git switch -c <name>` and confirm with
  `git branch --show-current` before committing.
- If the branch's last PR was already merged, don't stack new commits on the merged
  history: `git fetch origin main && git checkout -B <branch-name> origin/main`, then
  apply the new change as a fresh commit on top.
- If shell commands fail with tmux/memory errors, retry once. If they persist, stop and
  report the exact error — never continue with a text-only answer or fabricated results.

## Secrets

- API keys and credentials (`OLLAMA_API_KEY`, `BINANCE_KEY`, `BINANCE_SECRET`,
  `QDRANT_API_KEY`, any GitHub token) come from `ENV` only. Never hardcode them, never
  inline a value read from `.env` into application code, and never print them — in chat
  output, log lines, error messages, or committed files. `.env*` is already gitignored;
  keep it that way.
- Before committing, check `git status`/`git diff` for anything that looks like a secret,
  even in a file that seems unrelated (e.g. a debug print left in a spec).

## Safety & test addenda

- The `TradeDisabledError` invariant is absolute: any change touching `ExecutionTrader` or
  `BinanceFuturesClient` must keep — and extend, if the surface changed — the spec
  (`spec/binance_futures_client_spec.rb`) asserting that order placement raises.
- New desks/subscribers must be registered in the boot wiring (`lib/nemesis.rb`) and
  covered by an event-routing spec via `EventBus`.

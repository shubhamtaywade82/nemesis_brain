# AGENTS.md

Instructions for any coding agent (Claude, Qwen, Codex, etc.) working in this repository.

## Project quick facts

- Ruby trading-desk app. Entry point: `boot_nemesis.rb` → `lib/nemesis.rb` → `Nemesis.boot`.
- Desks live in `app/desks/` (`PortfolioManager`, `RiskManager`, `TradeJournal`, `TapeReader`,
  `ExecutionTrader`), communicating over `EventBus` (`app/event_bus.rb`) via Wisper pub/sub.
- Config and shared constants: `config/nemesis.rb` (module `Nemesis`).
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
  - `ruby boot_nemesis.rb` as a smoke test when boot wiring (`lib/nemesis.rb`,
    `app/desks/*`, `config/nemesis.rb`) changes — it should print the startup banner and
    stay running until interrupted; a crash on boot means something is broken
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

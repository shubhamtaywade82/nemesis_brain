# frozen_string_literal: true

require "dotenv/load" if ENV["NEMESIS_SKIP_DOTENV"] != "true"
require "ruby_llm"
require "oj"

Oj.default_options = { mode: :compat }

RubyLLM.configure do |config|
  config.ollama_api_key = ENV["OLLAMA_API_KEY"]
  config.ollama_api_base = ENV.fetch("OLLAMA_URL", "https://ollama.com/v1")
end

module NemesisBrain
  REASONING_MODEL = ENV.fetch("NEMESIS_REASONING_MODEL", "deepseek-v4-flash")
  EMBED_MODEL = ENV.fetch("NEMESIS_EMBED_MODEL", "deepseek-v4-flash")
  BINANCE_REST = ENV.fetch("BINANCE_REST", "https://fapi.binance.com")
  BINANCE_WS = ENV.fetch("BINANCE_WS", "wss://fstream.binance.com")
  DEFAULT_SYMBOL = ENV.fetch("NEMESIS_SYMBOL", "btcusdt")
  DEFAULT_EQUITY = ENV.fetch("NEMESIS_EQUITY", "10000").to_f
  PAPER_MODE = ENV.fetch("NEMESIS_PAPER_MODE", "true") == "true"
  LLM_ENABLED = ENV.fetch("NEMESIS_LLM_ENABLED", "false") == "true" && ENV["OLLAMA_API_KEY"].to_s.strip != ""
  QDRANT_ENABLED = ENV["QDRANT_URL"].to_s.strip != ""
end

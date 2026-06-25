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
  REASONING_MODEL = ENV.fetch("NEMESIS_REASONING_MODEL", "llama3:70b")
  EMBED_MODEL = ENV.fetch("NEMESIS_EMBED_MODEL", "nomic-embed-text")
  BINANCE_REST = ENV.fetch("BINANCE_REST", "https://testnet.binancefuture.com")
  BINANCE_WS = ENV.fetch("BINANCE_WS", "wss://stream.binancefuture.com")
  DEFAULT_SYMBOL = ENV.fetch("NEMESIS_SYMBOL", "btcusdt")
  DEFAULT_EQUITY = ENV.fetch("NEMESIS_EQUITY", "10000").to_f
  PAPER_MODE = ENV.fetch("NEMESIS_PAPER_MODE", "true") == "true"
  LLM_ENABLED = ENV["OLLAMA_API_KEY"].to_s.strip != ""
  QDRANT_ENABLED = ENV["QDRANT_URL"].to_s.strip != ""
end

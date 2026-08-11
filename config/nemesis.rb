# frozen_string_literal: true

require "dotenv/load" if ENV["NEMESIS_SKIP_DOTENV"] != "true"
require "ollama_client"
require "oj"

Oj.default_options = { mode: :compat }

module NemesisBrain
  REASONING_MODEL = ENV.fetch("NEMESIS_REASONING_MODEL", "gemma4:31b")
  EMBED_MODEL = ENV.fetch("NEMESIS_EMBED_MODEL", "nomic-embed-text")
  BINANCE_REST = ENV.fetch("BINANCE_REST", "https://fapi.binance.com")
  BINANCE_WS = ENV.fetch("BINANCE_WS", "wss://fstream.binance.com")
  DEFAULT_SYMBOL = ENV.fetch("NEMESIS_SYMBOL", "btcusdt")
  DEFAULT_EQUITY = ENV.fetch("NEMESIS_EQUITY", "10000").to_f
  PAPER_MODE = ENV.fetch("NEMESIS_PAPER_MODE", "false") == "true"
  LLM_ENABLED = ENV.fetch("NEMESIS_LLM_ENABLED", "false") == "true"
  QDRANT_ENABLED = ENV["QDRANT_URL"].to_s.strip != ""
  VERBOSE_LOGS = ENV["VERBOSE_LOGS"] == "true"

  module Log
    RESET = "\e[0m"
    COLORS = {
      cyan: "\e[36m",
      green: "\e[32m",
      red: "\e[31m",
      magenta: "\e[35m",
      yellow: "\e[33m",
      white: "\e[37m",
      gray: "\e[2m",
      bold_white: "\e[1;37m"
    }.freeze

    def self.colorize(text, color)
      "#{COLORS[color]}#{text}#{RESET}"
    rescue StandardError
      text
    end
  end

  class << self
    # Builds an Ollama::Config from the environment. Defaults to a local
    # Ollama instance; set OLLAMA_BASE_URL/OLLAMA_API_KEY(S) for Ollama Cloud.
    # API keys are picked up automatically by Ollama::Config from
    # OLLAMA_API_KEYS / OLLAMA_API_KEY, so only base_url and model need setting here.
    def ollama_config
      config = Ollama::Config.new
      config.base_url = ENV.fetch("OLLAMA_BASE_URL", ENV.fetch("OLLAMA_URL", config.base_url))
      config.model = REASONING_MODEL
      config
    end

    # Shared Ollama client, used as the default `ollama:` dependency for lobes
    # that reason with the LLM. Lobes still accept their own client for testing.
    def ollama_client
      @ollama_client ||= Ollama::Client.new(config: ollama_config)
    end
  end
end

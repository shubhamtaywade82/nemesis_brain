# frozen_string_literal: true

require "dotenv/load" if ENV["NEMESIS_SKIP_DOTENV"] != "true"
require "ruby_llm"
require "oj"

Oj.default_options = { mode: :compat }

RubyLLM.configure do |config|
  config.ollama_api_key = ENV["OLLAMA_API_KEY"]
  config.ollama_api_base = ENV.fetch("OLLAMA_URL", "https://ollama.com/v1")
end

module RubyLLM
  module Providers
    class Ollama
      module Embeddings
        module_function

        def embedding_url
          '/api/embed'
        end

        def render_embedding_payload(text, model:, dimensions:)
          { model: model, prompt: text }
        end

        def parse_embedding_response(response, model:, text:)
          data = response.body
          vectors = data['embedding']
          vectors = vectors.is_a?(Array) ? vectors : [vectors]
          input_tokens = data.dig('usage', 'prompt_tokens') || text.to_s.size
          Embedding.new(vectors:, model: model.to_s, input_tokens:)
        end
      end

      include Embeddings
    end
  end
end

module NemesisBrain
  REASONING_MODEL = ENV.fetch("NEMESIS_REASONING_MODEL", "gemma4:31b")
  EMBED_MODEL = ENV.fetch("NEMESIS_EMBED_MODEL", "gemma4:31b")
  BINANCE_REST = ENV.fetch("BINANCE_REST", "https://fapi.binance.com")
  BINANCE_WS = ENV.fetch("BINANCE_WS", "wss://fstream.binance.com")
  DEFAULT_SYMBOL = ENV.fetch("NEMESIS_SYMBOL", "btcusdt")
  DEFAULT_EQUITY = ENV.fetch("NEMESIS_EQUITY", "10000").to_f
  PAPER_MODE = ENV.fetch("NEMESIS_PAPER_MODE", "false") == "true"
  LLM_ENABLED = ENV.fetch("NEMESIS_LLM_ENABLED", "false") == "true" && ENV["OLLAMA_API_KEY"].to_s.strip != ""
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
end

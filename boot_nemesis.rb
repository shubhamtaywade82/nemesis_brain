#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/nemesis_brain"

puts "Booting Nemesis Cognitive Architecture..."
puts "  Model : #{NemesisBrain::REASONING_MODEL} (LLM #{NemesisBrain::LLM_ENABLED ? 'enabled' : 'paper mode'})"
puts "  Target: #{NemesisBrain::BINANCE_REST}"
puts "  Memory: #{NemesisBrain::QDRANT_ENABLED ? 'Qdrant' : 'in-memory'}"
puts "  Verbose logging: #{NemesisBrain::VERBOSE_LOGS ? 'ON' : 'OFF'}"
puts "  Paper Mode: #{NemesisBrain::PAPER_MODE ? 'YES' : 'NO'}"
puts ""

begin
  components = NemesisBrain.boot(
    symbol: NemesisBrain::DEFAULT_SYMBOL,
    equity: NemesisBrain::DEFAULT_EQUITY
  )

  components[:alpha_wave].execute
  puts "✓ Alpha Wave Loop started (60s interval)"

  components[:market_scanner].start(symbol: components[:symbol])
  puts "✓ MarketScanner online — streaming #{components[:symbol].upcase} tape"
  puts ""
  puts "🧠 Nemesis is awake and monitoring the market."
  puts "   Press Ctrl+C to shut down."
  puts ""

  # Graceful shutdown handler
  trap("INT") do
    puts "\n⚠️  Shutting down Nemesis..."
    components[:alpha_wave].shutdown
    sleep 1
    puts "✓ Shutdown complete."
    exit 0
  end

  sleep
rescue => e
  puts "❌ Boot failed: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n") if NemesisBrain::VERBOSE_LOGS
  exit 1
end

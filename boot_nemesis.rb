#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/nemesis"

puts "Booting Nemesis..."
puts "  Model : #{Nemesis::REASONING_MODEL} (LLM #{Nemesis::LLM_ENABLED ? 'enabled' : 'paper mode'})"
puts "  Target: #{Nemesis::BINANCE_REST}"
puts "  Memory: #{Nemesis::QDRANT_ENABLED ? 'Qdrant' : 'in-memory'}"
puts "  Verbose logging: #{Nemesis::VERBOSE_LOGS ? 'ON' : 'OFF'}"
puts "  Paper Mode: #{Nemesis::PAPER_MODE ? 'YES' : 'NO'}"
puts ""

begin
  components = Nemesis.boot(
    symbol: Nemesis::DEFAULT_SYMBOL,
    equity: Nemesis::DEFAULT_EQUITY
  )

  components[:macro_pulse].execute
  puts "✓ Macro pulse started (60s interval)"

  components[:tape_reader].start(symbol: components[:symbol])
  puts "✓ Tape reader online — streaming #{components[:symbol].upcase} tape"
  puts ""
  puts "📈 Nemesis is live and monitoring the market."
  puts "   Press Ctrl+C to shut down."
  puts ""

  # Graceful shutdown handler
  trap("INT") do
    puts "\n⚠️  Shutting down Nemesis..."
    components[:macro_pulse].shutdown
    sleep 1
    puts "✓ Shutdown complete."
    exit 0
  end

  sleep
rescue => e
  puts "❌ Boot failed: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n") if Nemesis::VERBOSE_LOGS
  exit 1
end

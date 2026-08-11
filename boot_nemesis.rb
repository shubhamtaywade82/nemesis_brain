#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require_relative "lib/nemesis"

puts "Booting QuantDesk..."
puts "  Model : #{QuantDesk::REASONING_MODEL} (LLM #{QuantDesk::LLM_ENABLED ? 'enabled' : 'paper mode'})"
puts "  Target: #{QuantDesk::BINANCE_REST}"
puts "  Memory: #{QuantDesk::QDRANT_ENABLED ? 'Qdrant' : 'in-memory'}"
puts "  Verbose logging: #{QuantDesk::VERBOSE_LOGS ? 'ON' : 'OFF'}"
puts "  Paper Mode: #{QuantDesk::PAPER_MODE ? 'YES' : 'NO'}"
puts ""

begin
  components = QuantDesk.boot(
    symbol: QuantDesk::DEFAULT_SYMBOL,
    equity: QuantDesk::DEFAULT_EQUITY
  )

  components[:macro_pulse].execute
  puts "✓ Macro pulse started (60s interval)"

  components[:tape_reader].start(symbol: components[:symbol])
  puts "✓ Tape reader online — streaming #{components[:symbol].upcase} tape"
  puts ""
  puts "📈 QuantDesk is live and monitoring the market."
  puts "   Press Ctrl+C to shut down."
  puts ""

  # Graceful shutdown handler
  trap("INT") do
    puts "\n⚠️  Shutting down QuantDesk..."
    components[:macro_pulse].shutdown
    sleep 1
    puts "✓ Shutdown complete."
    exit 0
  end

  sleep
rescue => e
  puts "❌ Boot failed: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n") if QuantDesk::VERBOSE_LOGS
  exit 1
end

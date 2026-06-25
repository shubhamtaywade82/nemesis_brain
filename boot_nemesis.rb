#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/nemesis_brain"

puts "Booting Nemesis Cognitive Architecture..."
puts "  Model : #{NemesisBrain::REASONING_MODEL} (LLM #{NemesisBrain::LLM_ENABLED ? 'enabled' : 'paper mode'})"
puts "  Target: #{NemesisBrain::BINANCE_REST}"
puts "  Memory: #{NemesisBrain::QDRANT_ENABLED ? 'Qdrant' : 'in-memory'}"
puts "  Verbose logging: #{NemesisBrain::VERBOSE_LOGS ? 'ON' : 'OFF'}"

components = NemesisBrain.boot(
  symbol: NemesisBrain::DEFAULT_SYMBOL,
  equity: NemesisBrain::DEFAULT_EQUITY
)

components[:alpha_wave].execute
puts "Alpha Wave Loop started (60s interval)"

components[:sensory].start(symbol: components[:symbol])
puts "SensoryCortex online — streaming #{components[:symbol].upcase} tape"
puts "Nemesis is awake."

sleep

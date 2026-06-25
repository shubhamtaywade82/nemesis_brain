# frozen_string_literal: true

require_relative "../config/nemesis"

ROOT = File.expand_path("..", __dir__)

%w[
  app/nervous_system
  app/clients/binance_futures_client
  app/lobes/hippocampus
  app/lobes/sensory_cortex
  app/lobes/prefrontal_cortex
  app/lobes/amygdala
  app/lobes/motor_cortex
  app/jobs/nightly_post_mortem
].each do |path|
  require_relative "../#{path}"
end

module NemesisBrain
  class << self
    def boot(symbol: DEFAULT_SYMBOL, equity: DEFAULT_EQUITY)
      nervous_system = NervousSystem.new
      binance = build_binance_client
      hippocampus = Hippocampus.new
      sensory = SensoryCortex.new(nervous_system)
      PrefrontalCortex.new(nervous_system:, hippocampus:)
      Amygdala.new(nervous_system:, equity:)
      MotorCortex.new(nervous_system:, binance:)

      alpha_wave = Concurrent::TimerTask.new(execution_interval: 60) do
        pulse_alpha_wave(nervous_system, binance)
      end

      {
        nervous_system:,
        binance:,
        hippocampus:,
        sensory:,
        alpha_wave:,
        symbol:
      }
    end

    private

    def build_binance_client
      BinanceFuturesClient.new(
        api_key: ENV.fetch("BINANCE_KEY", "paper"),
        secret_key: ENV.fetch("BINANCE_SECRET", "paper"),
        base_url: BINANCE_REST
      )
    end

    def pulse_alpha_wave(nervous_system, binance)
      funding = binance.get_funding_rate("BTCUSDT")
      open_interest = binance.get_open_interest("BTCUSDT")
      nervous_system.broadcast(:alpha_wave_pulse, { funding_rates: funding, open_interest: })
    rescue StandardError => e
      warn "[AlphaWave] #{e.message}"
    end
  end
end

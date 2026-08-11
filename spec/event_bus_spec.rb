# frozen_string_literal: true

require "spec_helper"

RSpec.describe EventBus do
  it "delivers tape signals to subscribed desks" do
    event_bus = described_class.new
    received = []

    listener = Class.new do
      define_method(:initialize) { |buffer| @buffer = buffer }
      define_method(:tape_signal_detected) { |payload| @buffer << payload }
    end.new(received)

    event_bus.subscribe(listener)
    event_bus.broadcast(
      :tape_signal_detected,
      {
        type: :absorption,
        direction: :long,
        delta: 1_200_000,
        price: 50_000,
        symbol: "BTCUSDT",
        context: "test"
      }
    )

    expect(received.length).to eq(1)
    expect(received.first[:direction]).to eq(:long)
  end
end

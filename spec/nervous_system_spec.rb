# frozen_string_literal: true

require "spec_helper"

RSpec.describe NervousSystem do
  it "delivers tape signals to subscribed lobes" do
    nervous_system = described_class.new
    received = []

    listener = Class.new do
      define_method(:initialize) { |buffer| @buffer = buffer }
      define_method(:tape_signal_detected) { |payload| @buffer << payload }
    end.new(received)

    nervous_system.subscribe(listener)
    nervous_system.broadcast(
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

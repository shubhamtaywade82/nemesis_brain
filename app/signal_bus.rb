# frozen_string_literal: true

require "wisper"

class SignalBus
  include Wisper::Publisher

  public :broadcast
end

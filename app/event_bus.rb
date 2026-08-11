# frozen_string_literal: true

require "wisper"

class EventBus
  include Wisper::Publisher

  public :broadcast
end

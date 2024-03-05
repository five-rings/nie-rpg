=begin
  Battle用ユニットの基底クラス
=end
class Battle::Unit::Base < Itefu::Unit::Base
  module Implement
    attr_reader :unit_state

    module State
      include Battle::Unit::State
    end

    def initialize(manager, *args, &block)
      @unit_state = State::INITIALIZED
      super
    end

    def finalize
      @unit_state = State::FINALIZED
      super
    end

    def on_unit_state_changed(old_state); end

    def change_unit_state(state)
      old = @unit_state
      @unit_state = state
      on_unit_state_changed(old)
    end
    alias :on_change_state_signaled :change_unit_state

  end
  include Implement
end


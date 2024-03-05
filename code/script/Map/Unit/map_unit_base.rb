=begin
=end
class Map::Unit::Base < Itefu::Unit::Base
  module Implement
    attr_reader :unit_state
    
    module State
      include Map::Unit::State
    end
    def state_started?
      case @unit_state
      when State::STARTED,
           State::OPENED
        true
      end
    end
    def state_opened?; @unit_state == State::OPENED; end

    def on_suspend; end
    def on_resume(context); end
    def on_unit_state_changed(old_state); end

    def initialize(manager, *args, &block)
      @unit_state = State::INITIALIZED
      super
    end
    
    def finalize
      @unit_state = State::FINALIZED
      super
    end
    
    def change_unit_state(state)
      old = @unit_state
      @unit_state = state
      on_unit_state_changed(old)
    end
    alias :on_change_state_signaled :change_unit_state

    # 実行状態を保存する
    def suspend(context)
      if result = on_suspend
        context[unit_id] = result
      end
    end
    alias :on_suspend_signaled :suspend
    
    # 保存された実行状態を元に再開する
    def resume(context)
      if context && (c = context[unit_id])
        on_resume(c)
      end
    end
    alias :on_resume_signaled :resume
  end
  include Implement
end

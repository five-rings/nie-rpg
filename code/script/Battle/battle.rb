=begin
  戦闘関連  
=end
module Battle

  class Result
    attr_accessor :outcome
    def event?; @event_battle; end

    def initialize(event_battle = true)
      @outcome = nil
      @event_battle = event_battle
    end
  end

  module ExitCode
    CLOSE = :close
    BATTLE_FINISHED = :battle
  end

  module Viewport
    include ::Viewport::Battle
  end

end

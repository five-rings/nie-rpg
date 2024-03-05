=begin
  スキル使用者のセリフ
=end
class Battle::Unit::Voice < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::VOICE; end

  def on_initialize(viewport)
    @view = manager
    @viewmodel = ViewModel.new(viewport)

    @view.add_layout(:all, "battle/voice", @viewmodel)
  end

  def show(message, subject)
    @viewmodel.dialogue = message
    @viewmodel.x = subject.head_x
    @viewmodel.y = subject.head_y
    @view.play_animation(:voice_window, :in)
  end

  def close
    @view.play_animation(:voice_window, :out)
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_accessor :x, :y
    attr_observable :dialogue

    def initialize(viewport)
      self.viewport = viewport
      self.dialogue = ""
      self.x = self.y = 0
    end
  end

end


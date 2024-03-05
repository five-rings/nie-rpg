=begin
=end
class Battle::Unit::Message < Battle::Unit::Base
  include Game::Unit::Message
  def default_priority; Battle::Unit::Priority::MESSAGE; end

  def initialize_controls(viewport)
    @view = manager
    @viewmodel = ViewModel.new(viewport)
    @view.add_layout(:all, "message", @viewmodel)

    @view.control(:message_text).add_callback(:message_decided, method(:message_decided))
    @view.control(:message_text).add_callback(:updated_drawing_info, method(:updated_drawing_info))
    @view.control(:message_text).add_callback(:message_shown, method(:message_shown))
    @view.control(:message_choices).add_callback(:decided, method(:choices_decided))
    @view.control(:message_choices).add_callback(:canceled, method(:choices_canceled))
    @view.control(:message_numeric_dial).add_callback(:decided, method(:numeric_decided))
    @view.control(:message_numeric_dial).custom_operation = method(:operate_numeric)
  end

  def finalize_controls
  end

  def message_context
    @viewmodel
  end

  def play_animation(control_name, anime_name)
    @view.play_animation(control_name, anime_name)
  end

  def focus
    @view.focus
  end

  def control(name)
    @view.control(name)
  end

  class ViewModel < Map::ViewModel::Message
    attr_accessor :viewport

    def initialize(viewport)
      self.viewport = viewport
      super()
    end
  end

end


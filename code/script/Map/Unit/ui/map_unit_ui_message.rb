=begin
  Map::Viewのメッセージウィンドウを操作する
=end
class Map::Unit::Ui::Message < Map::Unit::Base
  include Game::Unit::Message
  def default_priority; end

  def on_suspend
    {
      message: @message,
      message_queue: @message_queue,
    }
  end

  def on_resume(context)
    @message_queue ||= []
    @message_queue << context[:message] if context[:message]
    @message_queue.concat context[:message_queue]
  end

  def initialize_controls(viewport, map_view)
    @map_view = map_view
    @map_view.control(:message_text).add_callback(:message_decided, method(:message_decided))
    @map_view.control(:message_text).add_callback(:updated_drawing_info, method(:updated_drawing_info))
    @map_view.control(:message_text).add_callback(:message_shown, method(:message_shown))
    @map_view.control(:message_text).add_callback(:commanded_to_show_budget, method(:commanded_to_show_budget))
    @map_view.control(:message_choices).add_callback(:decided, method(:choices_decided))
    @map_view.control(:message_choices).add_callback(:canceled, method(:choices_canceled))
    @map_view.control(:message_numeric_dial).add_callback(:decided, method(:numeric_decided))
    @map_view.control(:message_numeric_dial).custom_operation = method(:operate_numeric)
  end

  def finalize_controls
    @map_view.control(:message_numeric_dial).custom_operation = nil
    @map_view.control(:message_numeric_dial).remove_callback(:decided, method(:numeric_decided))
    @map_view.control(:message_choices).remove_callback(:canceled, method(:choices_canceled))
    @map_view.control(:message_choices).remove_callback(:decided, method(:choices_decided))
    @map_view.control(:message_text).remove_callback(:commanded_to_show_budget, method(:commanded_to_show_budget))
    @map_view.control(:message_text).remove_callback(:message_shown, method(:message_shown))
    @map_view.control(:message_text).remove_callback(:updated_drawing_info, method(:updated_drawing_info))
    @map_view.control(:message_text).remove_callback(:message_decided, method(:message_decided))
    @map_view = nil
  end

  def message_context
    @map_view && @map_view.viewmodel.message_context
  end

  def play_animation(control_name, anime_name)
    @map_view.play_animation(control_name, anime_name)
  end

  def focus
    @map_view.focus
  end

  def control(name)
    @map_view.control(name)
  end

  def show(message, face_name, face_index, background, position)
    if state_started?
      super
    else
      message.split("\\p").each do |text|
        # 予約する
        @message_queue << MessageData.new(text, face_name, face_index, background, position)
      end
    end
  end

end

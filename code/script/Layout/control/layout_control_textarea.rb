=begin
=end
class Layout::Control::TextArea < Itefu::Layout::Control::TextArea
  attr_reader :skipped_by_move

  def initialize(*args)
    @skipping_handled = 0
    super
  end

  def update
    @skipping_handled -= 1 if @skipping_handled > 0
    super
  end

  def reset_skipped_by_move
    @skipped_by_move = nil
  end

  def handle_skipping(by_move = false)
    return if @skipping_handled > 0
    @skipping_handled = 2
    @skipped_by_move = by_move
    skip_message
  end

  def on_operation_instructed(code, *args)
    return if @skipping_handled > 0

    # 移動キーでもメッセージを送れるようにする
    # 移動キーはrepeated?で判定されているので、triggered?で判定しなおし、押しっぱなしでは送られないようにする
    case code
    when Operation::DECIDE,
         Operation::CANCEL
      handle_skipping(false)
    when Operation::MOVE_LEFT
      if (input = Application.input) && input.triggered?(Input::LEFT)
        handle_skipping(true)
      end
    when Operation::MOVE_UP
      if (input = Application.input) && input.triggered?(Input::UP)
        handle_skipping(true)
      end
    when Operation::MOVE_RIGHT
      if (input = Application.input) && input.triggered?(Input::RIGHT)
        handle_skipping(true)
      end
    when Operation::MOVE_DOWN
      if (input = Application.input) && input.triggered?(Input::DOWN)
        handle_skipping(true)
      end
    end
  end

end

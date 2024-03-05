=begin
  通知用ダイアログ
=end

if debug? && context.nil?
  imported = true
  context = Struct.new(:notice).new
  context.notice = "お知らせメッセージです"
end

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)

  attribute name: :notice_window,
            openness: 0

  _(Text) {
    extend Focusable
    attribute name: :notice_message,
              text_word_space: -2,
              text: binding { context.notice }
    self.focused = proc {|control|
      root.view.play_animation(:notice_window, :in)
    }
    self.unfocused = proc {|control|
      root.view.play_animation(:notice_window, :out)
    }
    self.operation_instructed = proc {|control, code|
      pop_focus if code != Operation::MOVE_POSITION
    }
  }
}

if debug? && imported
  self.add_callback(:layouted) {
    self.view.control(:notice_window).openness = 0xff
    self.view.push_focus(:notice_message)
  }
end


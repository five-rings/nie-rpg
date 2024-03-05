=begin
  通知用ダイアログ（顔グラ付き）
=end

if debug? && context.nil?
  imported = true
  context = Struct.new(:notice, :face_name, :face_index).new
  context.notice = "お知らせメッセージです"
  context.face_name = "Actor3"
  context.face_index = 1
end

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)

  attribute name: :notice_window,
            openness: 0


  _(Lineup) {
    attribute orientation: Orientation::HORIZONTAL,
              horizontal_alignment: Alignment::TOP
    _(Face) {
      attribute visibility: binding(Visibility::COLLAPSED, proc {|v|
                    v && v.empty?.! && Visibility::VISIBLE || Visibility::COLLAPSED
                  }) { context.face_name }, 
                margin: const_box(0, 12, 0, 0),
                image_source: binding(nil, proc {|v| image(v) }) { context.face_name },
                face_index: binding { context.face_index }
    }
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
}

if debug? && imported
  self.add_callback(:layouted) {
    self.view.control(:notice_window).openness = 0xff
    self.view.push_focus(:notice_message)
  }
end


=begin
  確認用ダイアログ
=end

if debug? && context.nil?
  imported = true
  context = Struct.new(:message, :choices).new
  context.message = "すか？"
  context.choices = ["はい", "いいえ"]
end

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)

  attribute horizontal_alignment: Alignment::CENTER,
            name: :dialog_window,
            openness: 0
  _(Cabinet) {
    extend Cursor
    self.focused = proc {|control|
      root.view.play_animation(:dialog_window, :in)
    }
    self.unfocused = proc {|control|
      root.view.play_animation(:dialog_window, :out)
    }
    attribute name: :dialog_list,
              horizontal_alignment: Alignment::CENTER,
              padding: const_box(5),
              items: binding { context.choices },
              item_template: proc {|item, item_index|
      _(Label) {
        attribute text: item, font_size: 20,
                  padding: const_box(2, 10)
      }
    }
    _(Text) {
      extend Unselectable
      attribute item_index: 0,
                font_size: 22,
                text_word_space: -2,
                margin: const_box(0, 0, 5),
                horizontal_alignment: Alignment::CENTER,
                text: binding { context.message }
    }
    break_line
  }
}

if debug? && imported
  self.add_callback(:layouted) {
    self.view.control(:dialog_window).openness = 0xff
    self.view.push_focus(:dialog_list)
  }
end


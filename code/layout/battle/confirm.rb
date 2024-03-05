=begin
  アクションを実行するか確認する
=end

viewport = context && context.viewport

if debug?
  attribute horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER
end

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW).play_speed = 2
  animation(:out, &Constant::Animation::CLOSE_WINDOW).play_speed = 2

  attribute name: :confirm_window,
            viewport: viewport,
            openness: 0

  _(Lineup) {
    extend Cursor
    attribute horizontal_alignment: Alignment::STRETCH,
              orientation: Orientation::VERTICAL,
              name: :confirm
    _(Label) {
      attribute text: "たたかう",
                margin: const_box(0, 0),
                padding: const_box(1,5),
                horizontal_alignment: Alignment::CENTER
    }
    _(Label) {
      attribute text: "やめる",
                margin: const_box(0, 0),
                padding: const_box(1,5),
                horizontal_alignment: Alignment::CENTER
    }
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:confirm_window, :in)
    self.view.push_focus(:confirm)
  }
end


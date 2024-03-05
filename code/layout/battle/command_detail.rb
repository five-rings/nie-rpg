=begin
  選択したコマンドアイテムの詳細情報
=end

viewport = context && context.viewport

if debug?
  attribute padding: box(0, 150, 0),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::CENTER

  unless context
    context = Struct.new(:description).new
    context.description = "アイテムの説明文です。"
  end
end

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW).play_speed = 2
  animation(:out, &Constant::Animation::CLOSE_WINDOW).play_speed = 2

  attribute name: :command_detail_window,
            width: 1.0, height: Size::AUTO,
            min_height: 96,
            viewport: viewport,
            openness: 0

  _(Text) {
    attribute width: 1.0, height: Size::AUTO,
              font_size: 20,
              text_word_space: -2,
              padding: const_box(0, 8, 0, 8),
              # no_auto_kerning: true,
              hanging: true,
              text: binding("NoData") { context.description }
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:command_detail_window, :in)
  }
end


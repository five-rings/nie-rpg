=begin
  アクション実行中に表示される吹き出し
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::TOP

  context = Struct.new(:dialogue, :x, :y).new("逃げ出す", 320, 240)
end


_(Sprite) {
  extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  extend Animatable
  animation(:in, &Constant::Animation::APPEAR_WINDOW).play_speed = 2
  animation(:out, &Constant::Animation::DISAPPEAR_WINDOW)

  attribute name: :voice_window,
            viewport: viewport,
            background: const_color(0, 0, 0, 0x7f),
            fill_padding: true,
            contents_creation: ContentsCreation::IF_LARGE,
            opacity: 0,
            padding: const_box(2, 7)

  self.add_callback(:drawn) {|c|
    c.sprite.x = unbox(context.x) - c.actual_width / 2
    c.sprite.y = unbox(context.y) - c.actual_height - 4
  }

  _(Label) {
    attribute text: binding { context.dialogue },
              font_size: 18
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:voice_window, :in)
  }
end


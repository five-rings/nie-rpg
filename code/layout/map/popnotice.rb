#
# マップ名の表示
#
viewport = context && context.viewport

if debug?
  context = Struct.new(:message).new
  context.message = "セーブしました"

  extend Background
  attribute background: Color.DarkSlateGrey
end

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::RIGHT,
            vertical_alignment: Alignment::BOTTOM,
            margin: const_box(15, 10)

  _(Sprite, 0, 0) {
    extend Animatable 
    extend Background
    ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation
    attribute name: :map_popnotice,
              viewport: binding { viewport },
              contents_creation: ContentsCreation::IF_LARGE,
              fill_padding: true,
              background: const_color(0xff, 0xff, 0xff, 0xff),
              opacity: 0

    animation(:show) {
      assign_target(:oy, control.sprite)
      add_key   0, :opacity, 0
      add_key  10, :opacity, 0xff
      add_key  80, :opacity, 0xff
      add_key  90, :opacity, 0
    }


    _(Label) {
      extend Background
      attribute text: binding { context.message },
                margin: const_box(1),
                padding: const_box(2, 15),
                font_size: 20,
                fill_padding: true,
                background: const_color(0, 0, 0, 0xe0)
    }
  }
}

self.add_callback(:layouted) {
  view.play_animation(:map_popnotice, :show)
} if debug?


#
# マップ名の表示
#
viewport = context && context.viewport

if debug?
  context = Struct.new(:map_name).new
  context.map_name = "エルキアの森"

  extend Background
  attribute background: Color.DarkSlateGrey
end

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM,
            margin: const_box(15, 10)

  _(Sprite, 0, 0) {
    extend Animatable 
    ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation
    attribute name: :map_name,
              viewport: binding { viewport },
              contents_creation: ContentsCreation::IF_LARGE,
              opacity: 0

    animation(:show) {
      add_key   0, :opacity, 0
      add_key  25, :opacity, 0xff
      add_key 190, :opacity, 0xff
      add_key 210, :opacity, 0
    }


    _(Label) {
      extend Background
      attribute text: binding { context.map_name },
                padding: const_box(2, 40),
                fill_padding: true,
                background: const_color(0, 0, 0, 0x9f)
    }
  }
}

self.add_callback(:layouted) {
  view.play_animation(:map_name, :show)
} if debug?


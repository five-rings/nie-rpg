#
# ロゴ画面のUI
#

_(Canvas) {
  extend SpriteTarget
  extend Animatable
  attribute width: 1.0, height: 1.0,
            name: :logo,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER,
            opacity: 0

  _(Label) {
    attribute text: "Five Rings",
#              margin: box(0, 0, 20, 0),
              font_size: 24
  }

  _(Label) {
    attribute text: "produced & designed  by ",
              margin: box(20, 0, 0, 0),
              font_size: 16
  } if false

  animation(:in) do
    add_key  0, :opacity, 0
    add_key 15, :opacity, 255
  end
  
  animation(:out) do
    add_key  0, :opacity, 255
    add_key 15, :opacity, 0
  end

  animation(:wait) do
    max_frame 120
  end
}

self.add_callback(:layouted) do
  view.play_animation(:logo, :in).finisher {
    view.play_animation(:logo, :wait).finisher {
      view.play_animation(:logo, :out)
    }
  }
end if debug


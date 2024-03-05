=begin
  タイトルを表示する
=end

message = Application.language.load_message(:title)
self.add_callback(:finalized) {
  Application.language.release_message(:title)
}

subtitles = []

i = 1
while msg = message.text(:"subtitle_#{i}")
 i += 1
 subtitles << msg
end

subtitle = subtitles.sample
caption = message.text(:caption) || "Nie"

_(Canvas) {
  # Main Title
  _(Sprite) {
    extend Animatable
    attribute name: :main_title,
              opacity: 0,
              margin: const_box(360, 0, 0, 50)

    animation(:show) do
      add_key  0, :opacity, 0
      add_key 15, :opacity, 0xff
    end

    animation(:hide) do
      add_key  0, :opacity, 0xff
      add_key 30, :opacity, 0
    end

    _(Label) {
      attribute text: caption,
                font_size: 48
    }
  }
  # Sub Title
  _(Sprite) {
    extend Animatable
    attribute margin: const_box(400, 0, 0, 50),
              name: :sub_title
    _(Label) {
      attribute text: "-#{subtitle}",
                font_size: 16
    }

    animation(:hide) do
      add_key  0, :opacity, 0xff
      add_key 30, :opacity, 0
    end
  }
  # To Mask Sub Title
  _(Sprite) {
    extend Animatable
    attribute margin: const_box(400, 0, 0, 0),
              name: :black_belt

    animation(:show) do
      # 黒帯を右にスライドさせる
      assign_target :x, control.sprite
      add_key   0, :x, nil
      add_key   5, :x, nil
      add_key  50, :x, 640
    end

    # 黒帯
    _(Empty) {
        extend Background, Drawable
        attribute width: 1.0, height: 20,
                  background: proc {|control, bitmap, x, y, w, h|
                    # 左端が透明グラデの黒帯
                    c1 = Color.Transparent
                    c2 = Color.Black
                    fw = 50
                    bitmap.gradient_fill_rect(x, y, fw, h, c1, c2)
                    bitmap.fill_rect(x+fw, y, w-fw, h, c2)
                  }
    }
  }
}

self.add_callback(:layouted) {
  view.play_animation(:main_title, :show)
  view.play_animation(:black_belt, :show).finisher {
    view.play_animation(:main_title, :hide)
    view.play_animation(:sub_title, :hide)
  }
} if debug?


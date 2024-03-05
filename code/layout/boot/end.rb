=begin
  ループエンドのエンディング演出
=end

if debug?
  context = Struct.new(:ending_type, :assigned).new
  context.ending_type = 10
end

message = Application.language.load_message(:ending)
self.add_callback(:finalized) {
  Application.language.release_message(:ending)
}


context.assigned = message.text(:"note_#{context.ending_type}")
label = (context.assigned || "").split(",")

caption = message.text(:caption)


_(Lineup) {
  attribute margin: const_box(370, 0, 0, 50),
            vertical_alignment: Alignment::BOTTOM

  # Main Title
  _(Sprite) {
    extend Animatable
    self.sprite.z = 0xff
    attribute name: :main_title,
              # margin: const_box(370, 0, 0, 50),
              opacity: 0

    animation(:show) do
      add_key   0, :opacity, 0
      add_key  60, :opacity, 0xff
      add_key 120, :opacity, 0xff
    end

    animation(:hide) do
      add_key  0, :opacity, 0xff
      add_key 30, :opacity, 0
    end

    _(Lineup) {
      attribute vertical_alignment: Alignment::BOTTOM

      caption.each_char do |c|
        _(Label) {
          attribute text: c,
                    # margin: const_box(0, -1, 0, 0),
                    font_size: 20
        }
      end
      _(Label) {
        attribute text: label[0],
                  margin: const_box(0, 0, -3, 6),
                  # font_bold: true,
                  font_size: 32
      }
    }
  }
  # Sub Title
  _(Canvas) {
    attribute vertical_alignment: Alignment::BOTTOM

  _(Sprite) {
    extend Animatable
    self.sprite.z = 0x0
    attribute name: :sub_title,
              margin: const_box(0, 0, 1, 16)
    _(Label) {
      attribute text: label[1],
                font_size: 18
    }

    animation(:hide) do
      add_key  0, :opacity, 0xff
      add_key 30, :opacity, 0
    end
  }
  # To Mask Sub Title
  _(Sprite) {
    extend Animatable
    self.sprite.z = 0x7f
    attribute name: :black_belt,
              margin: const_box(0, 0, 0, -50)
              # margin: const_box(400, 0, 0, 0)

    animation(:show) do
      # 黒帯を右にスライドさせる
      assign_target :x, control.sprite
      add_key   0, :x, nil
      # add_key   5, :x, nil
      add_key  200, :x, 640
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
}

self.add_callback(:layouted) {
  view.play_animation(:main_title, :show).finisher {
    view.play_animation(:black_belt, :show).finisher {
      view.play_animation(:main_title, :hide)
      view.play_animation(:sub_title, :hide)
    }
  }
} if debug?


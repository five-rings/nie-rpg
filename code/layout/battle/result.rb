=begin
  戦闘のリザルト表示ウィンドウ
=end

viewport = context && context.viewport

screen_width  = viewport && viewport.rect.width || Graphics.width
screen_height = viewport && viewport.rect.height || Graphics.height

if debug?
  context = Struct.new(:exp_earned, :money_earned, :actors, :items).new

  context.exp_earned = rand(100)
  context.money_earned = rand(100)

  Member = Struct.new(:face_name, :face_index, :job_name, :level, :exp, :exp_next)
  context.actors = [
    Member.new("Actor3", 2, "熟達の旅人", 1, 123, 1456),
    Member.new("Actor1", 1, "巫覡", 10, 1000, 1789),
    Member.new("People1", 3, "大物の妖精", 99, 100, Float::INFINITY),
  ]

  context.items = [nil]
end

proc_gradiation = proc {|control, bmp, x, y, w, h|
  if w > 1
    bmp.gradient_fill_rect(x, y, w, h, Color.White, Color.GoldenRod)
  else
    control.draw_background_color(bmp, x, y, w, h, Color.GoldenRod)
  end
}

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)

  attribute name: :result_window,
            viewport: viewport,
            width: Size::AUTO, height: 400,
            openness: 0

  _(Lineup) {
    attribute width: Size::AUTO, height: 1.0,
              horizontal_alignment: Alignment::STRETCH,
              vertical_alignment: Alignment::TOP,
              orientation: Orientation::VERTICAL

    #
    # Exp
    #
    _(Lineup) {
      attribute orientation: Orientation::HORIZONTAL,
                horizontal_alignment: Alignment::RIGHT,
                item_index: -1,
                height: 36
      _(CaptionedItem) {
        attribute height: 1.0,
                  margin: const_box(6, 20 , 6, 0),
                  icon_offset: -6,
                  icon_index: 262,
                  value: "+#{context.money_earned}"
      }
      _(Label) {
        attribute horizontal_alignment: Alignment::RIGHT,
                  margin: const_box(6, 0),
                  height: 1.0,
                  text: "Exp +#{context.exp_earned}"
      }
    }

    #
    # Actors
    #
    _(Cabinet) {
      attribute orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::STRETCH,
                content_alignment: Alignment::CENTER,
                items: binding { context.actors },
                item_template: proc {|item, item_index|
        _(Face) {
          attribute image_source: image(item.face_name),
                    face_index: item.face_index,
                    margin: const_box(0, 13)
        }
        _(CaptionedItem) {
          attribute caption: binding(0, proc {|v| "Lv.%2d" % v }) { item.level },
                    # width: 96+26,
                    min_width: 96,
                    value: item.job_name,
                    # padding: const_box(0, 5, 0),
                    independent: true,
                    font_size: 18
        }
        _(Label) {
          exp_obj = BindingObject.new(self, nil, proc {|v|
            nexp = unbox(item.exp_next)
            if nexp == Float::INFINITY
              # nexp = "‐"
              nexp = "--"
            end
            "#{unbox(item.exp)}/#{nexp}"
          })
          exp_obj.subscribe(item.exp)
          exp_obj.subscribe(item.exp_next)

          attribute horizontal_alignment: Alignment::RIGHT,
                    vertical_alignment: Alignment::CENTER,
                    font_size: 18,
                    width: 96,
                    height: 20,
                    text: exp_obj,
                    font_name: "Georgia",
                    independent: true
        }
        _(Gauge) {
          exp_obj = BindingObject.new(self, nil, proc {|v|
            unbox(item.exp).to_f / unbox(item.exp_next)
          })
          exp_obj.subscribe(item.exp)
          exp_obj.subscribe(item.exp_next)

          attribute orientation: Orientation::HORIZONTAL,
                    background: Color.Black,
                    gauge: proc_gradiation,
                    rate: exp_obj,
                    margin: const_box(2, 0),
                    independent: true,
                    # width: 96+16,
                    width: 96,
                    height: 3

        }
        break_line
      }
    }

    #
    # Items
    #
    _(Separator) {
      attribute width: 1, height: 3,
                margin: const_box(20, 20),
                padding: const_box(1),
                separate_color: Color.White,
                border_color: Color.Black
    }
    _(Cabinet) {
      attribute height: 1.0,
                orientation: Orientation::VERTICAL,
                content_alignment: Alignment::LEFT,
                padding: const_box(0, 10),
                items: binding { context.items },
                item_template: proc {|item, item_index|
      if item
        _(CaptionedItem) {
          attribute icon_index: item.icon_index,
                    caption: item.name,
                    margin: const_box(1, 2),
                    font_size: 20
        }
      else
        _(Label) {
          attribute text: "獲得アイテム: なし",
                    font_size: 20,
        }
      end
      }
    }
  }
}
}

self.add_callback(:layouted) {
  view.play_animation(:result_window, :in)
} if debug?

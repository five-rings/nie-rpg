#
# メッセージウィンドウ用
#
viewport = context && context.viewport

if debug? && context.!
  context = Struct.new(:message, :face_name, :face_index, :background, :alignment, :choices, :digit, :budget).new
  context.alignment = Alignment::CENTER
  context.choices = ["はい", "いいえ", "なにをいっているのやら"]
  context.digit = 8
  context.face_name = "Actor3"
  context.face_index = 1
  context.background = 1
  context.message = <<-EOM
だってお目の前にいなくなれば、お忘れなさいますわ。お世辞を仰ゃり附けていらっしゃるのですもの。わたくしなんぞより物事のお分かりになるお友達に、これまで度々お逢いになりましたでしょう。
  EOM
  context.budget = 12345

  extend Background
  attribute background: Color.DarkSlateGrey
end


currency_unit = Application.database.system.rawdata.currency_unit
currency_icon = 262

font_budget = ::Font.new.tap {|font|
  font.size = 22
}

_(Lineup) {
  attribute orientation: Orientation::VERTICAL,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: binding(nil, proc {|v|
                Alignment::BOTTOM == v ? v : Alignment::TOP
              }) { context.alignment },
            content_reverse: binding(false, proc {|v|
                Alignment::BOTTOM == v ? true : false
              }) { context.alignment },
            width: 1.0, height: 1.0

  # 余白を挟むための隙間
  _(Empty) {
    attribute width: 0,
              height: binding(0, proc {|v|
                  Alignment::CENTER == v ? -120*2-60 : 96/4
                }) { context.alignment }
  }

  # 黒背景
  _(Sprite, 544, 120) {
    extend Background
    extend Animatable
    attribute name: :message_sprite,
              width: 544, height: 120,
              viewport: viewport,
              background: proc {|control, bitmap, x, y, w, h|
                c1 = Color.Transparent
                c2 = const_color(0, 0, 0, 190)
                s = 8
                bitmap.gradient_fill_rect(x, y, w, s, c1, c2, true)
                bitmap.fill_rect(x, y+s, w, h-s*2, c2)
                bitmap.gradient_fill_rect(x, y+h-s, w, s, c2, c1, true)
              },
              opacity: 0,
              # opacity: binding(0, proc {|v|
              #     v == 1 ? 0xff : 0x00
              #   }) { context.background },
              margin: binding(nil, proc {|v|
                  Alignment::BOTTOM == v ? const_box(-120, 0, 0, 0) : const_box(0, 0, -120, 0)
                }) { context.alignment }
    animation(:in, &Constant::Animation::APPEAR_WINDOW)
    animation(:out, &Constant::Animation::DISAPPEAR_WINDOW)
  }

  # メッセージウィンドウ
  _(Window, 544, 120) {
    @window.z = 100
    extend Animatable 
    attribute name: :message_window,
              viewport: viewport,
              openness: 0,
              opacity: binding(0, proc {|v|
                  v == 0 ? 0xff : 0x00
                }) { context.background },
              contents_opacity: 0xff,
              width: 544, height: 120,
              # padding: const_box(4, 2),
              padding: const_box(4, 6),
              horizontal_alignment: Alignment::CENTER
    animation(:in, &Constant::Animation::OPEN_WINDOW)
    animation(:out, &Constant::Animation::CLOSE_WINDOW)

    _(Lineup) {
      attribute width: 1.0, height: 1.0,
                orientation: Orientation::HORIZONTAL,
                horizontal_alignment: Alignment::TOP
      _(Face) {
        attribute visibility: binding(Visibility::COLLAPSED, proc {|v|
                      v && v.empty?.! && Visibility::VISIBLE || Visibility::COLLAPSED
                    }) { context.face_name }, 
                  margin: const_box(0, 12, 0, 0),
                  image_source: binding(nil, proc {|v| image(v) }) { context.face_name },
                  face_index: binding { context.face_index }
      }
      _(TextArea) {
        extend Scrollable::CustomScroll
        self.custom_scroll = proc {|c, sy|
          # ホイールでメッセージ送り
          if sy > 0
            c.handle_skipping(true)
          end
        }
        attribute width: 1.0, height: 1.0,
                  name: :message_text,
                  text_word_space: Constant::Font::MESSAGE_WORD_SPACE,
                  font_size: Constant::Font::MESSAGE_SIZE,
                  hanging: true,
                  text: binding { context.message }
      }
    }
  }

  # 追加のウィンドウ
  _(Canvas) {
    attribute name: :message_additional,
              vertical_alignment: binding(nil, proc {|v|
                Alignment::BOTTOM == v ? v : Alignment::TOP
              }) { context.alignment },
              width: 544
    # 所持金
    _(Window, 0, 0, Constant::Z::Message::CHOICES) {
        extend Animatable 
        attribute name: :message_budget_window,
                  viewport: viewport,
                  openness: 0
        animation(:in, &Constant::Animation::OPEN_WINDOW)
        animation(:out, &Constant::Animation::CLOSE_WINDOW)
        _(CaptionedItem) {
          apply_font(font_budget)
          attribute icon_index: currency_icon,
                    value: binding(0, Constant::Proc::ADD_COMMA) { context.budget },
                    unit_offset: 2,
                    unit: currency_unit
        }
    }
    _(Decorator) {
      attribute width: 1.0, horizontal_alignment: Alignment::RIGHT
      # 選択肢のウィンドウ
      _(Window, 0, 0, Constant::Z::Message::CHOICES) {
        extend Animatable 
        attribute name: :message_choices_window,
                  viewport: viewport,
                  openness: 0,
                  horizontal_alignment: Alignment::CENTER
        animation(:in, &Constant::Animation::OPEN_WINDOW)
        anime_in = animation(:in_temp, &Constant::Animation::OPEN_WINDOW)
        animation(:in_wait, Itefu::Animation::Sequence).tap {|a|
          a.add_animation(anime_in)
          a.add_animation(Itefu::Animation::Wait.new(20))
        }
        animation(:out, &Constant::Animation::CLOSE_WINDOW)

        _(Lineup) {
          extend Cursor
          attribute name: :message_choices,
                    orientation: Orientation::VERTICAL,
                    vertical_alignment: Alignment::BOTTOM,
                    horizontal_alignment: Alignment::STRETCH,
                    margin: const_box(1, 6),
                    items: binding { context.choices },
                    item_template: proc {|item, item_index|
          _(Text) {
            attribute text: item,
                      padding: const_box(0, 5),
                      horizontal_alignment: Alignment::CENTER,
                      text_word_space: Constant::Font::MESSAGE_WORD_SPACE,
                      font_size: Constant::Font::MESSAGE_SIZE
          }
                    }
        }
      }
    }
    _(Decorator) {
      attribute width: 1.0, horizontal_alignment: Alignment::CENTER
      # 数値入力のウィンドウ
      _(Window, 0, 0, Constant::Z::Message::NUMERIC) {
        extend Animatable
        attribute name: :message_numeric_window,
                  viewport: viewport,
                  openness: 0,
                  margin: const_box(8, 0),
                  padding: const_box(2, 4)
        animation(:in, &Constant::Animation::OPEN_WINDOW)
        animation(:out, &Constant::Animation::CLOSE_WINDOW)

        _(Dial) {
          attribute name: :message_numeric_dial,
                    horizontal_alignment: Alignment::CENTER,
                    number: 0,
                    max_number: binding(0, proc {|v|
                      v && v > 0 ? (10 ** v) - 1 : 1
                    }) { context.digit },
                    loop: true,
                    padding: const_box(0, 0, 2, 4)
        }
      }
    }
  }

}

self.add_callback(:layouted) {
  view.play_animation(:message_window, :in)
  view.play_animation(:message_sprite, :in)
  view.play_animation(:message_choices_window, :in_wait).finisher {
    view.push_focus(:message_choices)
  }
  view.play_animation(:message_numeric_window, :in).finisher {
    # view.push_focus(:message_numeric_input)
  }
  view.play_animation(:message_budget_window, :in)
} if debug?



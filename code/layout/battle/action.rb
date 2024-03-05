=begin
  戦闘画面の行動順序表示
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(0, 5, 5, 640-150),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM

  context = Struct.new(:actions).new
  Action = Struct.new(:icon_index, :user_label, :action_name, :selecting)
  context.actions = [
    Action.new(17, "a", nil),
    nil,
    Action.new(17, "b", "かみつく", true),
    Action.new(17, " ", "逃げ出す"),
    nil,
    Action.new(17, " ", "スピリットアーツ", true),
    Action.new(17, "c", "Elemental Reel"),
  ]
end

font_element = ::Font.new.tap {|font|
  font.size = 18
}

message = Application.language.load_message(:battle)
self.add_callback(:finalized) {
  Application.language.release_message(:battle)
}

# $test_count ||= 0

_(Lineup) {
  extend SpriteTarget
  extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  attribute background: proc {|c, bmp, x, y, w, h|
              c.draw_background_color(bmp, x, y+30, w, h-30, const_color(0, 0, 0, 0x7f))
              bmp.gradient_fill_rect(x, y, w, 30, Color.Transparent, const_color(0, 0, 0, 0x7f), true)
            },
            padding: const_box(10, 1, 6, 9),
            fill_padding: true,
            viewport: viewport,
            contents_creation: ContentsCreation::IF_LARGE,
            orientation: Orientation::VERTICAL,
            vertical_alignment: Alignment::BOTTOM,
            horizontal_alignment: Alignment::LEFT,
            width: 1.0,
            content_reverse: true,
            items: binding([]) { context.actions },
            item_template: proc {|item, item_index|

  if item.nil?
    _(Separator) {
      attribute width: -2, height: 3,
                separate_color: Color.White,
                border_color: Color.Black,
                padding: const_box(1),
                margin: const_box(1)
    }
  else
    next if unbox(item.icon_index).nil?
    _(CaptionedItem) {
      # $test_count += 1
      extend SpriteTarget
      apply_font(font_element);

      self.add_callback(:drawn) {
        if unbox(item.selecting)
          self.sprite.ox = 8
        else
          self.sprite.ox = 0
        end
      }

      text_obj = BindingObject.new(self, nil, proc {|v|
        text = unbox(item.action_name) || message.text(:command_info_unknown_skill)
        if unbox(item.selecting)
          text
        else
          self.sprite.ox = 0
          Itefu::Utility::String.shrink(text, Language::Locale.full? ? 7 : 13)
        end
      })
      text_obj.subscribe(item.selecting)
      text_obj.subscribe(item.action_name)

      cap_obj = BindingObject.new(self, nil, proc {|v|
        if unbox(item.selecting)
          ""
        else
          unbox(item.user_label)
        end
      })
      cap_obj.subscribe(item.selecting)
      cap_obj.subscribe(item.user_label)

      attribute icon_index: binding { item.icon_index },
                caption: cap_obj,
                value: text_obj,
                font_out_color: binding(Color.Black, proc {|v| v && Color.MidnightBlue || Color.Black })  { item.selecting },
                # unit: $test_count,
                icon_size: 20,
                viewport: viewport,
                contents_creation: ContentsCreation::IF_LARGE,
                # width: 1.0,
                height: 21,
                vertical_alignment: Alignment::BOTTOM,
                padding: const_box(0, 0, 1)
    }
  end
            }
}


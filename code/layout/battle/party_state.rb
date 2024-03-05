=begin
  個別にではなくパーティ単位で表示するステート
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(0, 0, 150, 0),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM

  context = Struct.new(:actors, :party_states).new
  # StateData = Struct.new(:id, :count)
  # context.party_states = [
  #   StateData.new(1, rand(3)+1),
  #   StateData.new(3, rand(3)+1),
  #   StateData.new(4, rand(3)+1),
  # ]
  context.party_states = {
    1 => rand(7)+1,
    3 => rand(7)+1,
    4 => rand(7)+1,
  }
  context.actors = [nil] * 3
end

message = Application.language.load_message(:battle)
self.add_callback(:finalized) {
  Application.language.release_message(:battle)
}

database = Application.database
db_states = database.states

font_state = ::Font.new.tap {|font|
  font.size = 18
}

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            margin: const_box(5),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM
  _(Lineup) {
    extend SpriteTarget
    extend Background
    ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

    # attribute background: const_color(0, 0, 0, 0x7f),
    attribute background: proc {|c, bmp, x, y, w, h|
                c.draw_background_color(bmp, x, y, w-30, h, const_color(0, 0, 0, 0x7f))
                bmp.gradient_fill_rect(x+w-30, y, 30, h, const_color(0, 0, 0, 0x7f), Color.Transparent)
              },
              fill_padding: true,
              padding: const_box(7, 2, 6-7, 2),
              # padding: const_box(7, 20, 6-7, 2),
              opacity: binding(nil, proc {|v|
                  if v && v.empty?.!
                    0xff
                  else
                    0x00
                  end
                }) { context.party_states },
              viewport: viewport,
              contents_creation: ContentsCreation::IF_LARGE,
              orientation: Orientation::VERTICAL,
              items: binding { context.party_states },
              item_template: proc {|item ,item_index|
                state = db_states[item[0]]
                next unless state
                flag = item[1]

      _(Cabinet) {
        attribute orientation: Orientation::VERTICAL,
                  content_alignment: Alignment::CENTER,
                  items: binding { context.actors },
                  item_template: proc {|item ,item_index|
        num = unbox(context.actors).size

        _(Empty) {
          extend Background
          size = Itefu::Utility::Math.max(4 + (3 - num), 2)

          attribute width: size, height: size,
                    margin: const_box(1, 1, 1, 4),
                    background: (flag & (1 << item_index)) == 0 ? Color.Black : Color.White
        }

        # last entity
        break_line if item_index + 1 == num
                  }

        _(CaptionedItem) {
          apply_font(font_state)
          attribute icon_index: state && state.icon_index || 0,
                    icon_size: 20,
                    icon_offset: 4,
                    caption: state.name,
                    margin: const_box(1-7, 1, 1+7, 2),
                    vertical_alignment: Alignment::BOTTOM,
                    # width: 18,
                    height: 24
        }
      }

              }
      # _(Label) {
      #   attribute text: message.text(:party_state_label),
      #             font_size: 20,
      #             margin: const_box(1, 2),
      #             item_index: -1
      # }
  }
}

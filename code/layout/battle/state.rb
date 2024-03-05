=begin
  notableステートのアイコン表示
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER


  StateData = Struct.new(:turn_count)
  context = Struct.new(:state_data).new({
    20  => StateData.new(rand(10)),
    21  => StateData.new(rand(10)),
    22 => StateData.new(rand(10)),
  })
end

database = Application.database
db_states = database.states

font_state = ::Font.new.tap {|font|
  font.size = 18
  font.bold = true
  font.color = Color.Black
  font.out_color = Color.White
}

_(Sprite) {
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  attribute viewport: viewport,
            contents_creation: ContentsCreation::IF_LARGE,
            margin: const_box(0, 0, 32+4, 0),
            opacity: 0xcf

  _(Lineup) {
    attribute height: 24,
              items: binding { context.state_data },
              item_template: proc {|item, item_index|
                state = db_states[item[0]]
                next unless state && state.notable_state?
                turn_count = Constant::Utility.turn_count_label(item[1].turn_count)
                if turn_count
      _(CaptionedItem) {
        apply_font(font_state)
        attribute icon_index: state && state.icon_index || 0,
                  icon_size: 24,
                  icon_offset: -2,
                  caption: turn_count,
                  margin: const_box(0, -8, 0, 0),
                  vertical_alignment: Alignment::BOTTOM,
                  # width: 18,
                  height: 24
      }
                else
      _(Icon) {
        attribute icon_index: state.icon_index,
                  width: 24, height: 24
      }
                end
              }
  }
}


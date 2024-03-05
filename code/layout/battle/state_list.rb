=begin
  ステート一覧の表示
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
}

_(Sprite) {
  extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation
  sprite.z = 0xff

  attribute viewport: viewport,
            contents_creation: ContentsCreation::IF_LARGE,
            # opacity: 0xcf,
            background: const_color(0, 0, 0, 0x7f),
            fill_padding: true,
            margin: const_box(0, 0, 32+4+24, 0)

  _(Lineup) {
    attribute orientation: Orientation::VERTICAL,
              horizontal_alignment: Alignment::CENTER,
              items: binding { context.state_data },
              item_template: proc {|item, item_index|
                state = db_states[item[0]]
                next unless state
                label = state.special_flag(:label) || state.name
                next if label.empty?
      _(Label) {
        apply_font(font_state)
        attribute text: label
      }
              }
  }
}


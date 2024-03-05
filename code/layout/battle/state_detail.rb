=begin
  パーティメンバーのステートの詳細
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(0, 0, 160, 0),
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

  StateData = Struct.new(:id, :turn_count, :icon_index)
  context = Struct.new(:state_details).new
  context.state_details = [
    # 386,
    StateData.new(1, rand(10), 386),
    StateData.new(3, rand(10)),
    StateData.new(10, rand(10)),
    StateData.new(4, rand(10)),
    StateData.new(20, rand(10)),
    StateData.new(145, rand(10)),
    StateData.new(8, rand(10)),
    StateData.new(8, rand(10)),
    StateData.new(8, rand(10)),
    # 152
    StateData.new(nil, nil, 152),
    # StateData.new(8, rand(10)),
    StateData.new(8, rand(10)),
    # nil,
    # 202,
    StateData.new(7, rand(10), 202),
    StateData.new(145, rand(10)),
    StateData.new(8, rand(10)),
    StateData.new(8, rand(10)),
    StateData.new(40, 1),
    StateData.new(41, 2),
    StateData.new(36, 3),
    StateData.new(8, 4),
    StateData.new(81, 5),
    StateData.new(145, 6),
    StateData.new(8, 7),
    StateData.new(8, 8),
    StateData.new(8, 9),
    StateData.new(8, 10),
    StateData.new(8, 11),
    StateData.new(8, 12),
    StateData.new(8, 13),
    StateData.new(8, 14),
    StateData.new(8, 15),
  ]
end


message = Application.language.load_message(:battle)
self.add_callback(:finalized) {
  Application.language.release_message(:battle)
}

database = Application.database
db_states = database.states

item_size = 18
font_state = ::Font.new.tap {|font|
  font.size = item_size
}

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::CENTER

_(Cabinet) {
  extend Animatable
  extend SpriteTarget
  extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  animation(:in, &Constant::Animation::APPEAR_WINDOW).play_speed = 4
  animation(:out, &Constant::Animation::DISAPPEAR_WINDOW).play_speed = 2

  attribute background: const_color(0, 0, 0, 0x7f),
            name: :state_detail_window,
            min_width: 150, max_width: 1.0,
            margin: const_box(10, 20),
            padding: const_box(6),
            fill_padding: true,
            viewport: viewport,
            opacity: 0,
            contents_creation: ContentsCreation::IF_LARGE,
            height: 1.0,
            orientation: Orientation::VERTICAL,
            content_alignment: Alignment::LEFT,
            # visibility: binding(nil, proc {|v|
            #   v && v.empty?.! ? Visibility::VISIBLE : Visibility::HIDDEN
            # }) { context.state_details },
            items: binding { context.state_details },
            item_template: proc {|item, item_index|
  case item
  when nil
    # nothing
    _(Label) {
      apply_font(font_state)
      attribute text: message.text(:state_detail_nothing),
                margin: const_box(1, 0, 1, 26),
    }
  else
    if item.icon_index
      if item_index != 0
        _(Empty) { attribute width: 1, height: 8 }
      end
      target = _(Lineup) {
        attribute orientation: Orientation::VERTICAL
        _(Icon) {
          attribute icon_index: item.icon_index,
                    width: item_size, height: item_size,
                    # margin: const_box(item_index == 0 ? 0 : 8, 0, -10, 0)
                    margin: const_box(0, 0, -10, 0)
        }
      }
    else
      target = self
    end
    # state
    state = item.id && db_states[item.id]
    next unless state
    next if state.party_state?
    turn_count = item.turn_count
    target._(CaptionedItem) {
      apply_font(font_state)
      attribute icon_index: state && state.icon_index || 0,
                margin: const_box(1, 0, 1, 26),
                icon_size: item_size,
                icon_offset: 0,
                caption: Constant::Utility.turn_count_label(turn_count) || " ",
                unit: state.detail_name,
                vertical_alignment: Alignment::BOTTOM
    }
  end
            }
}

}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:state_detail_window, :in)
  }
end


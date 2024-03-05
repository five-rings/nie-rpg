=begin
  戦闘画面のコマンド選択
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(Graphics.height-160, 150, 5, 150),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM

  context = Struct.new(:actor_rindex, :items, :nomagic, :stated).new
  UsingItem = Struct.new(:icon_index, :short_name, :cost)
  context.actor_rindex = 0
  context.items = 30.times.map {|i| UsingItem.new(62+i, "アイテム#{'ン'*rand(5)}", 9+rand(2)*80) }
  context.items[0].short_name = "Thunder Bolt"
  context.items[1].short_name = "Thunder Storm"
  context.nomagic = false
  context.stated = true
end

message = Application.language.load_message(:battle)
self.add_callback(:finalized) {
  Application.language.release_message(:battle)
}

font_item = ::Font.new.tap {|font|
  font.size = Language::Locale.full? ? 20 : 18
}

_(Lineup) {
  attribute vertical_alignment: binding(Alignment::CENTER, proc {|v|
              case v
              when 0
                Alignment::BOTTOM
              when 1
                Alignment::CENTER
              else
                Alignment::TOP
              end
            }) { context.actor_rindex },
            orientation: Orientation::HORIZONTAL,
            height: 1.0

  # Command
  _(Window, 0, 0) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW).play_speed = 2
    animation(:out, &Constant::Animation::CLOSE_WINDOW).play_speed = 2

    attribute name: :command_menu_window,
              viewport: viewport,
              openness: 0

    _(Lineup) {
      extend Cursor
      attribute orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::STRETCH,
                name: :command_menu

      # Skills
      _(Label) { attribute text: message.text(:command_skill), padding: const_box(2), horizontal_alignment: Alignment::CENTER }
      # Magics
      _(Label) {
        extend SelectableIfVisible
        attribute text: message.text(:command_magic), padding: const_box(2), horizontal_alignment: Alignment::CENTER,
                  # visibility: binding(Visibility::COLLAPSED, proc {|v| v ? Visibility::COLLAPSED : Visibility::VISIBLE }) { context.nomagic }
                  visibility: Visibility::COLLAPSED
      }
      # Items
      _(Label) { attribute text: message.text(:command_item), padding: const_box(2), horizontal_alignment: Alignment::CENTER }
      # Equipments
      _(Label) { attribute text: message.text(:command_equip), padding: const_box(2), horizontal_alignment: Alignment::CENTER }
      # Information
      _(Label) {
        extend SelectableIfVisible
        attribute text: message.text(:command_info), padding: const_box(2), horizontal_alignment: Alignment::CENTER,
                  visibility: binding(Visibility::COLLAPSED, proc {|v| v ? Visibility::VISIBLE : Visibility::COLLAPSED }) { context.stated }
      }
    }
  }

  # List
  _(Window, 0, 0) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW).play_speed = 2
    animation(:out, &Constant::Animation::CLOSE_WINDOW).play_speed = 2

    attribute name: :command_items_window,
              width: 1.0, height: 1.0,
              viewport: viewport,
              openness: 0
    # @todo アイテムが大量に増えた場合に重くなるのをどこまで対処するか検討する
    _(Tile) {
      extend Drawable
      extend Cursor
      extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
      extend ScrollBar
      attribute width: 1.0, height: 1.0,
                scroll_direction: Orientation::VERTICAL,
                scroll_scale: 24+2,
                tile_width: 0.5, tile_height: 24+2,
                name: :command_items,
                padding: const_box(0, 5, 0, 0),
                items: binding { context.items },
                item_template: proc {|item, item_index|
        if item
          _(CaptionedItem) {
            apply_font(font_item)
            attribute icon_index: item.icon_index,
                      caption: Itefu::Utility::String.shrink(item.short_name, Language::Locale.full? ? 7 : 10),
                      value: item.cost,
                      icon_size: 24,
                      width: 1.0,
                      padding: const_box(1, 2)
          }
        else
          # _(Empty) { extend Unselectable }
          _(Empty) {
            # CaptionedItemのサイズが高さ+paddingなのでそれに合わせる
            attribute width: 1.0, height: 24+2
          }
        end
                }
    }
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:command_menu_window, :in)
    self.view.play_animation(:command_items_window, :in)
    self.view.push_focus(:command_items)
  }
end


=begin
  アイテム選択画面
=end

if debug?
  context = Struct.new( :sidemenu, :items, :description, :item_max, :dialog, :dialog_chara, :actions, :notice, :face_name, :face_index).new
  MenuItem = Struct.new(:id, :label, :noticed)
  context.sidemenu = [
    MenuItem.new(:back, "Items"),
    MenuItem.new(:back, "Tools"),
    MenuItem.new(:back, "Materials"),
    MenuItem.new(:back, "Weapons"),
    MenuItem.new(:back, "Armors"),
    MenuItem.new(:back, "Accessories"),
  ]
  ItemData = Struct.new(:item, :count, :disabled)
  database = Application.database
  db_items = database.items

  context.items = [
    ItemData.new(db_items[1], rand(100)),
    ItemData.new(db_items[2], rand(100), true),
    ItemData.new(db_items[3], rand(100)),
  ] * 7
  context.description = "説明文です"
  context.item_max = 10
  context.actions = [:item_use, :item_discard]
  context.notice = "お知らせ"

  Dialog = Struct.new(:message, :choices)
  context.dialog = Dialog.new("捨てますか", ["はい", "いいえ"])
end

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

_(Grid) {
  add_row_separator 130
  add_col_separator -120
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

  _(Decorator) {
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 0,
                vertical_alignment: Alignment::TOP
    _(Importer, "menu/sidemenu", context) {
    }
  }

  _(Window, 0, 0) {
    attribute width: 1.0, height: 1.0,
              grid_row: 1, grid_col: 0

    _(Tile, 0.5, 1.0/10) {
      extend Drawable
      extend Cursor
      extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
      extend ScrollBar
      attribute name: :itemlist,
                width: 1.0, height: 1.0,
                # page_size: 20, page_count: 0,
                scroll_direction: Orientation::VERTICAL,
                scroll_scale: 24+2,
                padding: const_box(0, 5, 0, 0),
                items: binding { context.items },
                item_template: proc {|item, item_index|
                  if item
      _(CaptionedItem) {
        if RPG::EquipItem === item.item && item.item.special_flag(:material)
          count = ""
        else
          count = item.count
        end
        attribute width: 1.0, height: 1.0,
                  margin: const_box(1, 3),
                  font_color: item.disabled ? Color.Grey : Color.White,
                  icon_index: item.item.icon_index,
                  caption: Itefu::Utility::String.shrink(item.item.name, Language::Locale.full? ? 13 : 20),
                  value: count
      }
                    else
        _(Empty) {
          attribute width: 1.0, height: 1.0,
                    margin: const_box(1, 3)
        }
                    end

                }
    }
  }
  
  _(Window, 0, 0) {
    attribute width: 1.0, height: 1.0,
              vertical_alignment: Alignment::STRETCH,
              grid_row: 1, grid_col: 1
    _(Text) {
      extend AutoScroll
      attribute text: binding { context.description },
                text_word_space: -2,
                padding: const_box(0, 10, 0, 6),
                hanging: true,
                # no_auto_kerning: true,
                scroll_wait: 30,
                scroll_speed_y: 1,
                width: 1.0, height: Size::AUTO
      self.add_callback(:binding_value_changed) {|c, name, old|
        if name == :text
          c.scroll_y = -1 if c.scroll_y && c.scroll_y > 0
          c.reset_scroll_wait
        end
      }
    }
  }

  # --------------------------------------------------
  # Action

  _(Lineup) {
    attribute orientation: Orientation::VERTICAL,
              horizontal_alignment: Alignment::STRETCH,
              grid_row: 1, grid_col: 0

  _(Window, 0, 0) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW)
    animation(:out, &Constant::Animation::CLOSE_WINDOW)
    attribute horizontal_alignment: Alignment::CENTER,
              name: :item_action_window,
              openness: 0

    _(Lineup) {
      extend Cursor
      attribute name: :item_action_list,
                padding: const_box(1),
                orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::STRETCH,
                items: binding { context.actions },
                item_template: proc {|item, item_index|
      _(Label) {
        attribute text: message.text(item),
                  padding: const_box(1, 3),
                  horizontal_alignment: Alignment::CENTER
      }
                }
    }
              }
  _(Window, 0, 0) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW)
    animation(:out, &Constant::Animation::CLOSE_WINDOW)
    attribute horizontal_alignment: Alignment::STRETCH,
              name: :item_numeric_window,
              openness: 0

    _(Lineup) {
      extend Unselectable
      attribute orientation: Orientation::HORIZONTAL,
                horizontal_alignment: Alignment::RIGHT
      num_obj = observable(0)
      _(Label) {
        extend Unselectable
        attribute text: "×"
      }
      _(Dial) {
        attribute name: :item_numeric_dial,
                  max_number: binding { context.item_max },
                  min_number: 1,
                  number: binding { num_obj },
                  loop: true
      }
    }
  }
  }

  # --------------------------------------------------
  # Target

  _(Importer, "dialog_chara", context.dialog_chara) {
    attribute grid_row: 1, grid_col: 0
  }

  # --------------------------------------------------
  # Confirmation

  _(Importer, "dialog", context.dialog) {
    attribute grid_row: 1, grid_col: 0
  }

  _(Importer, "notice_face", context) {
    attribute grid_row: 1, grid_col: 0
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:itemlist)
    # self.view.control(:item_action_window).openness = 0xff
    # self.view.control(:item_numeric_window).openness = 0xff
    # self.view.push_focus(:item_action_list)
    self.view.control(:dialog_chara_window).openness = 0xff
    self.view.push_focus(:dialog_chara_list)
  }
end


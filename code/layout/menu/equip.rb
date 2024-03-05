=begin
  装備画面
=end

if debug?
  context = Struct.new(:charamenu, :items, :description, :equips, :notice, :extra_texts).new
  context.charamenu = (1..3).each.map {|i|
    vm = Layout::ViewModel::CharaMenu.new
    vm.copy_from_actor Application.savedata_game.actors[i]
    vm
  }

  ItemData = Struct.new(:item, :count)
  database = Application.database
  db_items = database.armors
  context.items = [nil] + [
    ItemData.new(db_items[1], rand(100)),
    ItemData.new(db_items[2], rand(100)),
    ItemData.new(db_items[3], rand(100)),
  ] * 7
  context.description = "説明文です"
  context.notice = "お知らせ"
  context.extra_texts = 6.times.map {|i| "能力#{i}" }

  context.equips = [
    db_items[1],
    db_items[2],
    db_items[3],
    db_items[4],
    nil,
    nil,
  ]
end

font_item = ::Font.new.tap {|font|
  font.size = 20
}
font_empty = ::Font.new.tap {|font|
  font.size = 20
  font.color = Color.Grey
}

font_extra_text = ::Font.new.tap {|font|
  font.size = 21
}

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

empty_slots = [
  message.text(:equip_slot_weapon),
  message.text(:equip_slot_shield),
  message.text(:equip_slot_head),
  message.text(:equip_slot_armor),
  message.text(:equip_slot_accessory),
  message.text(:equip_slot_accessory),
]

_(Grid) {
  add_row_separator 164+8*2

  _(Importer, "menu/charamenu", context) {
    attribute grid_row: 0, grid_col: 0
  }

  _(Grid) {
    add_col_separator -120
    attribute width: 1.0, height: 1.0,
              grid_row: 1, grid_col: 0

    # 説明欄
    _(Window, 0, 0) {
      attribute width: 1.0, height: 1.0,
                vertical_alignment: Alignment::STRETCH,
                grid_row: 0, grid_col: 1
      _(Text) {
        extend AutoScroll
        attribute text: binding { context.description },
                  text_word_space: -2,
                  hanging: true,
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

    _(Grid) {
      add_row_separator 0.5
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 0

      _(Decorator) {
        attribute width: 1.0, height: 1.0,
                  grid_row: 0, grid_col: 0,
                  vertical_alignment: Alignment::BOTTOM
        _(Window, 0, 0) {
          extend Animatable
          animation(:in, &Constant::Animation::OPEN_WINDOW)
          animation(:out, &Constant::Animation::CLOSE_WINDOW)
          attribute width: 1.0,
                    min_height: 100, max_height: 1.0,
                    openness: 0,
                    name: :extra_window

          _(Cabinet) {
            self.add_callback(:binding_value_changed) {|c, name, old|
              if name == :items
                item = c.send(name)
                ext_window = root.view.control(:extra_window)
                if item && item.empty?.!
                  anime = ext_window.animation_data(:out)
                  anime.finish if anime && anime.playing?
                  if ext_window.openness != 255
                    root.view.play_animation(:extra_window, :in)
                  end
                else
                  anime = ext_window.animation_data(:in)
                  anime.finish if anime && anime.playing?
                  if ext_window.openness != 0
                    root.view.play_animation(:extra_window, :out)
                  end
                end
              end
            }

            attribute width: 1.0, # height: 1.0,
                      orientation: Orientation::HORIZONTAL,
                      content_alignment: Alignment::BOTTOM,
                      items: binding { context.extra_texts },
                      item_template: proc {|item, item_index|
            _(Label) {
              apply_font(font_extra_text)
              attribute text: item, margin: const_box(0, 2)
            }
                      }
          }
        }
      }

      # 装備スロット
      _(Window, 0, 0) {
        attribute width: 1.0, #height: 172,
                  grid_row: 0, grid_col: 0
        _(Lineup) {
          extend Cursor
          attribute width: 1.0, #height: 1.0,
                    name: :equiplist,
                    orientation: Orientation::VERTICAL,
                    items: binding { context.equips },
                    item_template: proc {|item, item_index|
          if item
            _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0, height: 26,
                      icon_index: item.icon_index,
                      caption: item.name
            }
          else
            _(Label) {
              apply_font(font_empty)
              # extend Background
              attribute width: 1.0, height: 24,
                        padding: const_box(2, 3, 2, 24),
                        margin: const_box(1),
                        # background: Color.Black,
                        text: empty_slots[item_index]
            }
          end
                    }

        }
      }

      # アイテム一覧
      _(Window, 0, 0) {
        attribute width: 1.0, height: 1.0,
                  grid_row: 1, grid_col: 0
        _(Lineup) {
          extend Drawable
          extend Cursor
          extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
          extend ScrollBar
          attribute width: 1.0, height: 1.0,
                    scroll_direction: Orientation::VERTICAL,
                    scroll_scale: 24+2,
                    name: :itemlist,
                    orientation: Orientation::VERTICAL,
                    padding: const_box(0, 5, 0, 0),
                    items: binding { context.items },
                    item_template: proc {|item, item_index|
          if item
            _(CaptionedItem) {
              apply_font(font_item)
              attribute width: 1.0, height: 26,
                        margin: const_box(1, 3),
                        icon_index: item.item.icon_index,
                        caption: item.item.name,
                        value: item.count
            }
          else
            _(Label) {
              apply_font(font_item)
              attribute width: 1.0, height: 26,
                        margin: const_box(1, 3),
                        horizontal_alignment: Alignment::CENTER,
                        vertical_alignment: Alignment::CENTER,
                        text: message.text(:equip_unequip)
            }
          end
                    }
        }
      }
    }

    _(Decorator) {
      attribute grid_row: 0, grid_col: 0,
                width: 1.0, height: 1.0,
                horizontal_alignment: Alignment::CENTER,
                vertical_alignment: Alignment::CENTER

      _(Importer, "notice", context) {
      }
    }
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:equiplist)
  }
end


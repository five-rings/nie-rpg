#
# 武器合成
#

if debug? && context.!
  context = Struct.new(:items, :description, :target_item, :slots, :extra_texts, :item_max, :media, :notice, :actors, :level, :equipped).new

  database = Application.database
  db_items = database.items

  context.items = [nil] + [
    db_items[1],
    db_items[2],
    db_items[3],
  ] * 30
  # context.description = "説明文です"
  context.description = "説明文です\na1\na2\na3\na4\na5"
  context.target_item = db_items[1]
  context.slots = [
    RPG::EquipItem::ExtraItemData.new(db_items[1], 3),
    RPG::EquipItem::ExtraItemData.new(db_items[2], 1),
    nil,
  ]
  context.extra_texts = 6.times.map {|i| "能力#{i}" }
  context.item_max = 10

  context.actors = (1..3).each.map {|i| Application.savedata_game.actors[i] }
  context.level = 10
  context.equipped = true

  MediumData = Struct.new(:item, :count, :focused)
  context.media = [
    MediumData.new(db_items[1], 999, false),
    MediumData.new(db_items[2], 999, true),
    MediumData.new(db_items[3], 999, false),
  ]

  context.notice = "\\C[18]\\I[10]\\i[14]\\C[0]が足りません。長いメッセージの自動折り返し"
end

font_addition = ::Font.new.tap {|font|
  font.color = Color.Grey
}

font_extra_text = ::Font.new.tap {|font|
  font.size = 21
}

font_equipped = ::Font.new.tap {|font|
  font.size = 20
  font.color = Color.Snow
  font.out_color = Color.RoyalBlue
}

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

chara_max = Application.database.actors.size


_(Grid) {
  add_row_separator -220
  attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::CENTER

  _(Lineup) {
    attribute width: 1.0, height: 1.0,
              orientation: Orientation::VERTICAL,
              horizontal_alignment: Alignment::RIGHT,
              grid_col: 0, grid_row: 1

    # 素材アイテムの個数
    _(Window, 0, 0) {
      attribute width: 50*3+8*2, height: 40
      _(Lineup) {
        attribute width: 1.0, height: 1.0,
                  orientation: Orientation::HORIZONTAL,
                  items: binding { context.media },
                  item_template: proc {|item, item_index|
          _(CaptionedItem) {
            attribute width: 50, height: 1.0,
                      icon_index: item.item.icon_index,
                      font_size: 20,
                      font_out_color: binding(Color.Black, proc {|v|
                        v ? Color.Blue : Color.Black
                      }) { item.focused },
                      value: binding { item.count }
        }
                  }
      }
    }

  _(Lineup) {
    attribute width: 1.0, height: 1.0,
              orientation: Orientation::VERTICAL,
              content_reverse: true

    # 選択中のアイテムの詳細
    _(Window, 0, 0) {
      attribute width: 1.0,
                min_height: 132
      _(Cabinet) {
        attribute width: 1.0, #height: 1.0,
                  orientation: Orientation::HORIZONTAL,
                  content_alignment: Alignment::BOTTOM,
                  items: binding { context.extra_texts },
                  item_template: proc {|item, item_index|
        _(Label) {
          apply_font(font_extra_text)
          attribute text: item, margin: const_box(0, 2)
        }
                  }

        _(Lineup) {
          attribute width: 1.0, height: 32,
                    item_index: -1,
                    margin: const_box(0, 2, 3, 0),
                    orientation: Orientation::HORIZONTAL,
                    vertical_alignment: Alignment::BOTTOM,
                    items: binding {context.actors },
                    item_template: proc {|item, item_index|
                      _(Chara) {
                        attribute image_source: image(item.chara_name),
                                  chara_index: item.chara_index,
                                  chara_pattern: 1
                      }
                    }
          _(Label) {
            apply_font(font_extra_text)
            attribute item_index: chara_max + 1,
                      margin: const_box(0, 0, 0, 5),
                      text: binding(nil, proc {|v| v && "Lv.#{v}" || "" }) { context.level }
          }
          _(Label) {
            apply_font(font_equipped)
            attribute item_index: chara_max + 2,
                      visibility: binding(nil, proc {|v| v ? Visibility::VISIBLE : Visibility::HIDDEN }) { context.equipped },
                      text: message.text(:synth_equipped)
          }
        }
      }
    }

    # 選択中のアイテムと合成された素材
    _(Window, 0, 0) {
      attribute width: 1.0,
                height: Size::AUTO, max_height: 1.0
      _(Lineup) {
        attribute width: 1.0, height: Size::AUTO,
                  orientation: Orientation::VERTICAL

        # Caption
        _(CaptionedItem) {
          extend Unselectable
          attribute width: 1.0, height: 26,
                    icon_index: binding(0, proc {|v| v && v.icon_index || 0}) { context.target_item },
                    caption: binding("", proc {|v| v.name }) { context.target_item }
        }

        # Slots
      _(Lineup) {
        ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation
        extend SpriteTarget
        extend Drawable
        extend Cursor
        extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
        extend ScrollBar
        attribute width: 1.0, height: Size::AUTO,
                  contents_creation: ContentsCreation::IF_LARGE,
                  # max_height: -132,
                  max_height: 1.0,
                  name: :slotlist,
                  padding: const_box(0, 3, 0, 16),
                  orientation: Orientation::VERTICAL
        # _(CaptionedItem) {
        #   extend Unselectable
        #   attribute width: 1.0, height: 26,
        #             margin: const_box(0, 0, 0, -16),
        #             item_index: -1,
        #             icon_index: binding(0, proc {|v| v && v.icon_index || 0}) { context.target_item },
        #             caption: binding("", proc {|v| v.name }) { context.target_item }
        # }
        attribute items: binding { context.slots },
                  item_template: proc {|item, item_index|
          if item
            if item.item.special_flag(:hidden).!
              _(CaptionedItem) {
                attribute width: 1.0, height: 26,
                          icon_index: item.item.icon_index,
                          caption: item.item.name,
                          value: item.count != 1 ? item.count : ""
              }
            else
              _(Empty) {
                extend Unselectable
                attribute visibility: Visibility::COLLAPSED
              }
            end
          else
            _(Label) {
              apply_font(font_addition)
              attribute width: 1.0, height: 26,
                        padding: const_box(1, 3),
                        text: message.text(:synth_nothing)
            }
          end
        }
      }
      }
    }
  }
  }


  _(Grid) {
    add_col_separator -120
    attribute width: 1.0, height: 1.0,
              grid_col: 0, grid_row: 0

    # アイテム一覧
    _(Window, 0, 0) {
      attribute width: 1.0, height: 1.0,
                grid_col: 0, grid_row: 0
      _(Tile, 0.5, 1.0/12) {
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
            attribute width: 1.0, height: 1.0,
                      padding: const_box(1, 3),
                      icon_index: item.icon_index,
                      caption: item.name
          }
        else
          if item_index == 0
            _(Label) {
              attribute width: 1.0, height: 1.0,
                        padding: const_box(1, 3, 1, 3+24),
                        text: message.text(:synth_nothing)
            }
          else
            _(Empty) {}
          end
        end
                  }
        # self.add_callback(:cursor_moved){|control, operation, next_index, current_index|
        #   if next_index && Empty === control.child_at(next_index)
        #     scroll_to_child(next_index)
        #     operate_move(operation)
        #   end
        # }
      }
    }

    # アイテム説明
    _(Window, 0, 0) {
      attribute width: 1.0, height: 1.0,
                padding: const_box(0, 0, 5, 0),
                vertical_alignment: Alignment::STRETCH,
                grid_row: 0, grid_col: 1
      _(Text) {
        extend AutoScroll
        attribute text: binding { context.description },
                  text_word_space: -2,
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

    # 個数入力
    _(Decorator) {
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 0,
                horizontal_alignment: Alignment::CENTER,
                vertical_alignment: Alignment::CENTER
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
          num_obj = observable(1)
          _(Label) {
            extend Unselectable
            attribute text: "×"
          }
          _(Dial) {
            self.focused = proc {|control|
              root.view.play_animation(:item_numeric_window, :in)
            }
            self.unfocused = proc {|control|
              root.view.play_animation(:item_numeric_window, :out)
            }
            attribute name: :item_numeric_dial,
                      max_number: binding { context.item_max },
                      min_number: 1,
                      number: binding { num_obj },
                      loop: true
          }
        }
      }
    }

    # Notification
    _(Decorator) {
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 0,
                horizontal_alignment: Alignment::CENTER,
                vertical_alignment: Alignment::CENTER
      _(Importer, "notice", context) {
        child.max_width = 0.8
      }
    }
  }
}

self.add_callback(:layouted) {
  push_focus(:itemlist)
  push_focus(:notice_message)
} if debug?



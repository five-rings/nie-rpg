#
# ショップ
#

viewport = context && context.viewport

TARGET_STATUS = [:max_hp, :max_mp, :attack, :defence, :magic, :footwork, :accuracy, :evasion, :luck]

if debug? && context.!
  context = Struct.new(:budget, :items, :description, :has_count, :item, :item_max, :notice, :actors, :currency_unit, :currency_icon, :item_to_compare, :actors_for_status, :actor_params).new
  context.budget = 12345678
  context.has_count = 12
  context.description = "商品の説明です。"
  context.notice = "お知らせ"
  context.actors = (1..3).each.map {|i| Application.savedata_game.actors[i] }
  # context.currency_unit = "枚"
  # context.currency_icon = 10

  Item = Struct.new(:icon_index, :name, :price, :disabled, :item_color)
  context.items = 3.times.map {|i|
    Item.new(rand(10)+10, "ItemName#{i}", rand(10000), i == 1)
  }
  context.items[0].item_color = Itefu::Color.create(35,55,243)

  context.item = Item.new(10, "ItemToBuy", 123)
  context.item_to_compare = RPG::EquipItem.new
  context.item_to_compare.name = "TestItem 2 buy"
  context.item_to_compare.icon_index = 10
  context.item_to_compare.price = 123
  context.item_to_compare.params[3] = 10
  context.item_to_compare.etype_id = 0
  context.item_max = 30

  context.actors_for_status = context.actors
  context.actor_params = Hash[ context.actors.map {|actor|
      [actor.actor_id, Hash[ TARGET_STATUS.map {|key|
        [key, rand(30)-15,]
      }]
      ]
  }]

end

font_item = ::Font.new.tap {|font|
  font.size = 20
}
font_item_disabled = font_item.clone.tap {|font|
  font.color = Color.DarkGrey
}

font_mp = ::Font.new.tap {|font|
  font.size = 19
}

font_item_plus = font_item.clone.tap {|font|
  font.out_color = Color.Blue
}
font_item_minus = font_item.clone.tap {|font|
  font.out_color = Color.Red
}

currency_unit = Application.database.system.rawdata.currency_unit
# currency_icon = 361
currency_icon = 262

message = Application.language.load_message(:map)
self.add_callback(:finalized) {
  Application.language.release_message(:map)
}

equip_slots = [
  # EquipItem#etype_id と対応する
  message.text(:equip_slot_weapon),
  message.text(:equip_slot_shield),
  message.text(:equip_slot_head),
  message.text(:equip_slot_armor),
  message.text(:equip_slot_accessory),
]

proc_apply_font = proc {|c, name, old_value|
  case name
  when :param
    if param = unbox(c.param)
      if param < 0
        c.apply_font(font_item_minus)
      elsif param > 0
        c.apply_font(font_item_plus)
      else
        c.apply_font(font_item)
      end
    end
  end
}


_(Canvas) {
  attribute width: 1.0, height: 1.0,
            margin: const_box(6),
            horizontal_alignment: Alignment::RIGHT

  # 商品一覧
  _(Window, 0, 0, Constant::Z::Message::SHOP) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW)
    animation(:out, &Constant::Animation::CLOSE_WINDOW)
    attribute viewport: viewport,
              name: :shop_itemlist_window,
              openness: 0,
              width: 275, height: 1.0
    _(Lineup) {
      extend Drawable
      extend Cursor
      extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
      extend ScrollBar
      attribute width: 1.0, height: 1.0,
                scroll_direction: Orientation::VERTICAL,
                scroll_scale: 24+2,
                name: :shop_itemlist,
                orientation: Orientation::VERTICAL,
                padding: const_box(2, 5, 2, 0),
                items: binding { context.items },
                item_template: proc {|item, item_index|
      _(CaptionedItem) {
        if item.disabled
          apply_font(font_item_disabled)
        elsif item.item_color
          font = font_item.clone
          font.color = item.item_color
          apply_font(font)
        else
          apply_font(font_item)
        end
        attribute width: 1.0, height: 26,
                  margin: const_box(1, 0),
                  padding: const_box(1, 2),
                  vertical_alignment: Alignment::BOTTOM,
                  icon_index: item.icon_index,
                  caption: item.name,
                  value: binding(0, Constant::Proc::ADD_COMMA_WITHOUT_0)  { item.price },
                  unit: binding(nil, proc {|v|
                    case v
                    when nil
                      item.disabled ?  message.text(:shop_price_rewarded) : message.text(:shop_price_underqualified)
                    when 0
                      message.text(:shop_price_changable)
                    else
                      (unbox(context.currency_unit) || currency_unit)
                    end
                  }) { item.price }
      }
                }
    }
  }

  _(Lineup) {
    attribute width: 1.0, height: 1.0,
              orientation: Orientation::VERTICAL,
              horizontal_alignment: Alignment::LEFT
    # 所持金
    _(Window, 0, 0, Constant::Z::Message::SHOP) {
      extend Animatable
      animation(:in, &Constant::Animation::OPEN_WINDOW)
      animation(:out, &Constant::Animation::CLOSE_WINDOW)
      attribute viewport: viewport,
                name: :shop_budget_window,
                openness: 0,
                width: 130, height: 40
      _(CaptionedItem) {
        apply_font(font_item)
        attribute width: 1.0, height: 1.0,
                  # margin: const_box(0, 0, 0, -4),
                  icon_index: binding(0, proc {|v| v || currency_icon }) { context.currency_icon },
                  value: binding(0, Constant::Proc::ADD_COMMA) { context.budget },
                  unit_offset: 2,
                  unit: binding("", proc {|v| v || currency_unit }) { context.currency_unit }
      }
    }

    # メニュー
    _(Window, 0, 0, Constant::Z::Message::SHOP) {
      extend Animatable
      animation(:in, &Constant::Animation::OPEN_WINDOW)
      animation(:out, &Constant::Animation::CLOSE_WINDOW)
      attribute viewport: viewport,
                name: :shop_menu_window,
                openness: 0,
                padding: const_box(2),
                width: 130, height: Size::AUTO
      _(Lineup) {
        extend Cursor
        attribute width: 1.0, height: Size::AUTO,
                  name: :shop_menu,
                  orientation: Orientation::VERTICAL
        _(Label) {
          attribute text: message.text(:shop_buy),
                    width: 1.0, item: :buy,
                    padding: const_box(1, 5)
        }
        _(Separator) {
          extend Unselectable
          attribute width: 1.0, height: 3,
                    padding: const_box(1),
                    margin: const_box(1),
                    separate_color: Color.White,
                    border_color: Color.Black
        }
        _(Label) {
          extend Unselectable
          attribute text: message.text(:shop_sell),
                    padding: const_box(1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_usable),
                    width: 1.0, item: :sell_usable,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_consumable),
                    width: 1.0, item: :sell_consumable,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_tool),
                    width: 1.0, item: :sell_tool,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_material),
                    width: 1.0, item: :sell_material,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_weapon),
                    width: 1.0, item: :sell_weapon,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_armor),
                    width: 1.0, item: :sell_armor,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
        _(Label) {
          attribute text: message.text(:shop_sell_accessory),
                    width: 1.0, item: :sell_accessory,
                    margin: const_box(0, 0, 0, 15),
                    padding: const_box(1, 1, 1, 5)
        }
      }
    }

    # 説明文
    _(Decorator) {
      attribute width: -275, height: 1.0,
                vertical_alignment: Alignment::BOTTOM
      _(Window, 0, 0, Constant::Z::Message::SHOP) {
        extend Animatable
        animation(:in, &Constant::Animation::OPEN_WINDOW)
        animation(:out, &Constant::Animation::CLOSE_WINDOW)
        attribute width: 1.0, height: 150 +32-25,
                  name: :shop_description_window,
                  openness: 0,
                  margin: const_box(0, 0, 0, 0),
                  viewport: viewport
        _(Lineup) {
          attribute width: 1.0, height: 1.0,
                    orientation: Orientation::VERTICAL,
                    content_reverse: true
          _(Lineup) {
            attribute width: 1.0, height: 32,
                      orientation: Orientation::HORIZONTAL,
                      vertical_alignment: Alignment::BOTTOM,
                      items: binding { context.actors },
                      item_template: proc {|item, item_index|
                        _(Chara) {
                          attribute image_source: image(item.chara_name),
                                    chara_index: item.chara_index,
                                    chara_pattern: 1
                        }

                        # MP for skills
                        _(Label) {
                          apply_font(font_mp)
                          attribute text: "MP:#{item.mmp}"
                        } if unbox(context.currency_unit)

                        # Equipped
                        c = view.control(:shop_itemlist)
                        itemlist = unbox(context.items)
                        if c && itemlist
                          idx = c.cursor_index
                          goods = idx && itemlist[idx]
                          _(Icon) {
                            attribute icon_index: goods.item.icon_index,
                                      margin: const_box(0, 0, -2, -4)
                          } if goods && item.equipped?(goods.item)
                        end

                        # diff of Def for Armors
=begin
                        _(Label) {
                          apply_font(font_mp)
                          attribute text: binding(nil, proc {|v|

          
                            shopdef = (RPG::EquipItem === v && v.special_flag(:material).!) ? v.params[3] : 0
                            eq = item.equipment(
                                                                             Definition::Game::Equipment.convert_from_rgss3(v.etype_id)
                            )
                            eqdef = eq && eq.params[3] || 0

                            "%+d" % (shopdef - eqdef)
                          }) { context.item_to_compare },
                          visibility: binding(nil, proc {|v| (RPG::EquipItem === v && v.special_flag(:material).!)? Visibility::VISIBLE : Visibility::COLLAPSED }) { context.item_to_compare }
                        } unless unbox(context.currency_unit) # not for skill shop
=end
                      }
            _(Label) {
              attribute width: 1.0, height: 25,
                        font_size: 19,
                        independent: true,
                        margin: const_box(0, 5, 0, 0),
                        vertical_alignment: Alignment::BOTTOM,
                        horizontal_alignment: Alignment::RIGHT,
                        text: binding(nil, proc {|v| v ? "#{message.text(:shop_posession)}#{v}" : "" }) { context.has_count }
            }
          }
          _(Text) {
            attribute width: 1.0, height: 1.0,
                      padding: const_box(0, 6, 0, 4),
                      # no_auto_kerning: true,
                      hanging: true,
                      name: :shop_description,
                      independent: true,
                      text_word_space: Constant::Font::MESSAGE_WORD_SPACE,
                      font_size: Constant::Font::MESSAGE_SIZE,
                      text: binding("") { context.description }
          }
        }
      }
    }
  }

  # ステータス比較
  _(Window, 0, 0, Constant::Z::Message::SHOP) {
    extend Animatable
    animation(:in, &Constant::Animation::OPEN_WINDOW)
    animation(:out, &Constant::Animation::CLOSE_WINDOW)
    attribute viewport: viewport,
              name: :shop_status_window,
              margin: const_box(0, 275, 0, 0),
              padding: const_box(5, 0, 5, 5),
              # width: 200, # height: 1.0,
              openness: 0

    _(Lineup) {
      attribute orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::CENTER

    _(Lineup) {
      attribute horizontal_alignment: Alignment::RIGHT,
                # width: 1.0,
                items: binding { context.actors_for_status },
                item_template: proc {|item, item_index|

        # キャラごとのステータス値
        _(Lineup) {
          attribute orientation: Orientation::VERTICAL,
                    horizontal_alignment: Alignment::STRETCH,
                    margin: const_box(0, 5)
          _(Chara) {
            attribute image_source: image(item.chara_name), chara_index: item.chara_index,
                      chara_pattern: 1
          }
          TARGET_STATUS.each {|key|
            _(Label) {
              @param = binding { context.actor_params[item.actor_id][key] }.bind(self, :param)
              def self.param; @param; end
              add_callback(:binding_value_changed, &proc_apply_font)
              proc_apply_font.call(self, :param)

              attribute text: binding(0, proc {|v|
                            v && v != 0 && (
                              "%+d" % v
                            ) || message.text(:shop_status_zero)
                          }) { context.actor_params[item.actor_id][key] },
                        independent: true,
                        horizontal_alignment: Alignment::RIGHT,
                        padding: const_box(0, 2, 0, 0),
                        margin: const_box(2, 0, 0)
            }
          }
        }
      }

      # ステータス項目名
      _(Lineup) {
        attribute orientation: Orientation::VERTICAL,
                  horizontal_alignment: Alignment::RIGHT,
                  item_index: -1,
                  padding: const_box(32, 0, 0)
        TARGET_STATUS.each {|key|
            _(Label) {
              apply_font(font_item)
              attribute text: message.text(:"shop_status_#{key}"),
                        margin: const_box(2, 0, 0)
            }
          }
      }
    }
      _(Label) {
        apply_font(font_item_plus)
        attribute text: binding(nil, proc {|v|
          v && equip_slots[v.etype_id]
        }) { context.item_to_compare },
                  margin: const_box(6, 0, 0, 0)
      }
    }
  }

  # 個数入力
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::CENTER
    _(Window, 0, 0, Constant::Z::Message::SHOP) {
      extend Animatable
      animation(:in, &Constant::Animation::OPEN_WINDOW)
      animation(:out, &Constant::Animation::CLOSE_WINDOW)
      attribute name: :shop_numeric_window,
                openness: 0,
                viewport: viewport
      _(Lineup) {
        attribute orientation: Orientation::VERTICAL,
                  horizontal_alignment: Alignment::STRETCH
        _(CaptionedItem) {
          attribute icon_index: binding(nil, proc {|v| v && v.icon_index }) { context.item },
                    caption: binding(nil, proc {|v| v && v.name }) { context.item }
        }
        num_obj = observable(1)
        _(Lineup) {
          attribute orientation: Orientation::HORIZONTAL,
                    horizontal_alignment: Alignment::RIGHT
          _(Label) {
            attribute text: "×"
          }
          _(Dial) {
            attribute name: :shop_numeric_dial,
                      min_number: 1,
                      max_number: binding { context.item_max },
                      number: binding { num_obj },
                      loop: false

            # 0個=購入しなかった場合はSEをキャンセルにする
            def self.on_decide_effect(index)
              if self.number > 0
                Itefu::Sound.play_shop_se
              else
                Sound.play_cancel_se
              end
            end

            # 上限下限から更にもう一度入力したときのみループする
            add_callback(:value_changed) {|control, index, num, newnum|
              next unless input = Application.input
              if num == newnum
                if num == control.min_number
                  if input.triggered?(Input::DOWN)
                    control.number = control.max_number
                    Sound.play_select_se
                  end
                else
                  if input.triggered?(Input::UP)
                    control.number = control.min_number
                    Sound.play_select_se
                  end
                end
              end
            }
          }
        }
        _(Separator) {
          attribute width: 1, height: 3,
                    padding: const_box(1),
                    separate_color: Color.White,
                    border_color: Color.Black,
        }
        _(CaptionedItem) {
          sum_obj = BindingObject.new(self, nil, proc {|v|
            n = unbox(num_obj)
            i = unbox(context.item)
            n && i && Constant::Proc::ADD_COMMA.call(n * unbox(i.price))
          })
          sum_obj.subscribe(num_obj)
          sum_obj.subscribe(context.item)

          attribute value: sum_obj,
                    unit: binding("", proc {|v| v || currency_unit }) { context.currency_unit }
        }
      }
    }
  }

  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::CENTER
    _(Importer, "notice", context) {
      attribute viewport: viewport
      self.window.z = Constant::Z::Message::SHOP
    }
  }
}


self.add_callback(:layouted) {
  view.play_animation(:shop_itemlist_window, :in)
  view.play_animation(:shop_budget_window, :in)
  view.play_animation(:shop_description_window, :in)
  view.play_animation(:shop_menu_window, :in)
  view.play_animation(:shop_status_window, :in)
  # view.play_animation(:shop_numeric_window, :in)
  view.push_focus(:shop_menu)
  view.push_focus(:shop_itemlist)
  # view.push_focus(:shop_numeric_dial)
} if debug?

=begin
  キャラ選択メニュー
=end

if debug? && context.nil?
  context = Struct.new(:charamenu).new
  context.charamenu = (1..3).each.map {|i|
    vm = Layout::ViewModel::CharaMenu.new
    vm.copy_from_actor Application.savedata_game.actors[i]
    vm
  }
end

font_item = ::Font.new.tap {|font|
  font.size = 20
}
font_job = ::Font.new.tap {|font|
  if Language::Locale.half?
    font.size = 18
  else
    font.size = 19
  end
}

element_size = 20

font_arrow = ::Font.new.tap {|font|
  font.size = 14
  font.color = const_color(0xff, 0xff, 0xff, 0xef)
}

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

elements = Application.database.system.rawdata.elements
element_icons = [
  nil, 
  131,
  130,
  135,
  96,
  99,
  101,
  100,
  97,
  98,
  103,
]

db_state = Application.database.states

obj_arrow_visibility = observable(Visibility::HIDDEN)

_(Window, 0, 0) {
  attribute width: 1.0

    _(Lineup) {
      extend Drawable
      extend Cursor
      extend Scrollable.option(:ControlViewer, :CursorScroller)
      extend Scrollable::CustomScroll
      extend Scrollable::Option::LazyScrolling
      extend ScrollBar

      self.custom_scroll = proc {|control, value|
        index = control.cursor_index
        if value < 0
          index -= 1
        elsif value > 0
          index += 1
        else
          next
        end
        control.cursor_index = Itefu::Utility::Math.loop_size(control.items.size, index)
        nil
      }

      attribute name: :charamenu,
                width: 1.0, height: 1.0,
                scroll_direction: Orientation::HORIZONTAL,
                scroll_scale: 164,
                padding: const_box(0, 0, 5, 0),
                orientation: Orientation::HORIZONTAL,
                items: binding([]) { context.charamenu },
                item_template: proc {|item, item_index|

        self.focused = proc {|control|
          obj_arrow_visibility.value = Visibility::VISIBLE
        }
        self.unfocused = proc {|control|
          obj_arrow_visibility.value = Visibility::HIDDEN
        }

        _(Cabinet) {
          attribute width: 164, height: 1.0,
                    padding: const_box(5, (164-96)/2-10),
                    horizontal_alignment: Alignment::LEFT,
                    content_alignment: Alignment::CENTER,
                    orientation: Orientation::HORIZONTAL

          _(Label) {
            apply_font(font_arrow)
            attribute width: 30, height: 30,
                      margin: const_box(-15, 0, -15, -30),
                      horizontal_alignment: Alignment::RIGHT,
                      visibility: binding { obj_arrow_visibility },
                      text: "◀"
          }
          _(Face) {
            attribute image_source: image(item.face_name),
                      face_index: item.face_index,
                      margin: const_box(2, 9, 10),
          }
          _(Label) {
            apply_font(font_arrow)
            attribute width: 30, height: 30,
                      margin: const_box(-15, -30, -15, 0),
                      horizontal_alignment: Alignment::LEFT,
                      visibility: binding { obj_arrow_visibility },
                      text: "▶"
          }

          break_line

          _(CabinetInverse) {
            attribute width: 1.0, height: 70,
                      vertical_alignment: Alignment::BOTTOM,
                      margin: const_box(-70-30, 8, 0, 8),
                      items: binding([]) { item.state_ids },
                      item_template: proc {|state_id, index|
              next unless state = db_state[state_id]
              _(Icon) {
                attribute icon_index: state.icon_index
              } if state.icon_index != 0
            }
          }

          break_line

          _(Label) {
            apply_font(font_item)
            attribute margin: const_box(-5-10, 0, 1, 0),
                      vertical_alignment: Alignment::BOTTOM,
                      text: "Lv.#{item.level}"
          }
          _(Label) {
            apply_font(font_job)
            attribute margin: const_box(-5-10, 0, 1, 0),
                      width: 1.0, height: font_item.size,
                      horizontal_alignment: Alignment::RIGHT,
                      vertical_alignment: Alignment::BOTTOM,
                      text: item.job_name
          }

          # HP/MP
          _(Gauge) {
            hp_obj = BindingObject.new(self, nil, proc {|v|
              unbox(item.hp).to_f / unbox(item.max_hp)
            })
            hp_obj.subscribe(item.hp)
            hp_obj.subscribe(item.max_hp)

            attribute width: 0.5, height: 2,
                      background: Color.Black,
                      gauge: Color.Crimson,
                      margin: const_box(20, 2, 0, 0),
                      rate: hp_obj
          }
          _(Gauge) {
            mp_obj = BindingObject.new(self, nil, proc {|v|
              unbox(item.mp).to_f / unbox(item.max_mp)
            })
            mp_obj.subscribe(item.mp)
            mp_obj.subscribe(item.max_mp)

            attribute width: 1.0, height: 2,
                      background: Color.Black,
                      gauge: Color.RoyalBlue,
                      margin: const_box(20, 0, 0, 2),
                      rate: mp_obj
          }
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 0.5,
                      margin: const_box(3-20, 2, 0, 0),
                      independent: true,
                      caption: "HP",
                      value: binding { item.hp }
          }
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3-20, 0, 0, 2),
                      independent: true,
                      caption: "MP",
                      value: binding { item.mp }
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 0.5,
                      name: :"param_hp#{item_index}",
                      margin: const_box(-3, 2, 0, 0),
                      independent: true,
                      caption: "Max",
                      value: binding { item.max_hp },
                      underline: Color.White,
                      underline_offset: -2
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_mp#{item_index}",
                      margin: const_box(-3, 0, 0, 2),
                      independent: true,
                      caption: "Max",
                      value: binding { item.max_mp },
                      underline: Color.White,
                      underline_offset: -2
          }

          # Basic params
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_attack#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:attack),
                      value: binding { item.attack_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_defence#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:defence),
                      value: binding { item.defence_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_magic#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:magic),
                      value: binding { item.magic_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_footwork#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:footwork),
                      value: binding { item.footwork_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_accuracy#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:accuracy),
                      value: binding { item.accuracy_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_evasion#{item_index}",
                      margin: const_box(3, 0, 0, 0),
                      independent: true,
                      caption: message.text(:evasion),
                      value: binding { item.evasion_detail },
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      name: :"param_luck#{item_index}",
                      margin: const_box(3, 0),
                      independent: true,
                      caption: message.text(:luck),
                      value: binding { item.luck_detail },
                      underline: Color.White,
                      underline_offset: -1
          }

          # Elements
          elements.each.with_index do |element_name, element_id|
            next unless element_name && element_name.empty?.!
            _(CaptionedItem) {
              attribute width: 30+6,
                        icon_index: element_icons[element_id],
                        icon_size: element_size,
                        margin: const_box(0, 1),
                        value: binding { item.elements[element_id] || 0 },
                        vertical_alignment: Alignment::BOTTOM,
                        font_size: 18,
                        font_bold: binding(nil, proc {|v| v && v < 0 }) { item.elements[element_id] },
                        font_color: binding(nil, proc {|v|
                            v && v < 0 ? Color.Red : Color.White
                          }) { item.elements[element_id] },
                        font_out_color: binding(nil, proc {|v|
                            v && v > 0 ? Color.Blue : Color.Black
                          }) { item.elements[element_id] }
            }
          end

          break_line

          _(Separator) { attribute  height: 1, width: 1.0, margin: const_box(3, 0), separate_color: Color.White }

          # States
          _(Cabinet) {
            attribute width: 1.0,
                      # height: element_size,
                      orientation: Orientation::HORIZONTAL,
                      items: binding { item.immuned_states },
                      item_template: proc {|state_id, state_index|
                next unless state = db_state[state_id]
                _(Icon) {
                  attribute icon_index: state.icon_index,
                            margin: const_box(0, 2, 0, 1),
                            width: element_size, height: element_size
                }
              # 耐性上位三種を表示するバージョン
              # _(CaptionedItem) {
              #   res = item.actor.state_resistance(state.id)
              #   attribute icon_index: state.icon_index,
              #             width: 30+4,
              #             icon_size: element_size,
              #             margin: const_box(0, 2),
              #             value: res,
              #             vertical_alignment: Alignment::BOTTOM,
              #             font_size: 18,
              #             font_bold: res < 0,
              #             font_color: res < 0 ? Color.Red : Color.White,
              #             font_out_color: res > 0 ? Color.Blue : Color.Black
              # }
                      }

          }

        }
                }
    }
}

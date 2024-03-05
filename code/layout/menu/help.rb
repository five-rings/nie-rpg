=begin
  ヘルプに表示するパラメータ画面
=end

if debug? && context.nil?
  context = Struct.new(:actors).new
  context.actors = (1..3).each.map {|i| Application.savedata_game.actors[i] }
end

font_item = ::Font.new.tap {|font|
  font.size = 19
}
font_job = ::Font.new.tap {|font|
  if Language::Locale.half?
    font.size = 18
  else
    font.size = 19
  end
}
font_state = ::Font.new.tap {|font|
  font.size = 18
  font.color = const_color(0x34, 0x34, 0x34)
  font.outline = false
}

element_size = 20

font_exp = ::Font.new.tap {|font|
  font.size = 18
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

proc_gradiation = proc {|control, bmp, x, y, w, h|
  if w > 1
    bmp.gradient_fill_rect(x, y, w, h, Color.White, Color.GoldenRod)
  else
    control.draw_background_color(bmp, x, y, w, h, Color.GoldenRod)
  end
}


_(Sprite, 0, 0) {
  attribute width: 164

    _(Lineup) {
      extend Drawable
      # extend Cursor
      # extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
      # extend ScrollBar
      attribute name: :member_list,
                width: 1.0, height: 1.0,
                # scroll_direction: Orientation::HORIZONTAL,
                # scroll_scale: 164,
                padding: const_box(0, 0, 5, 0),
                orientation: Orientation::HORIZONTAL,
                items: binding([]) { context.actors },
                item_template: proc {|item, item_index|
        _(Cabinet) {
          attribute width: 164, height: 1.0,
                    padding: const_box(5, (164-96)/2-10),
                    horizontal_alignment: Alignment::CENTER,
                    content_alignment: Alignment::CENTER,
                    orientation: Orientation::HORIZONTAL


          if item.face_name.empty?
            _(Empty) {
              extend Background
              attribute width: 96+(10-8)*2, height: 96,
                        background: color(0, 0, 0, 0x3f),
                        margin: const_box(0, 8, 8),
            }
          else
            _(Face) {
              attribute image_source: image(item.face_name),
                        face_index: item.face_index,
                        margin: const_box(0, 10, 8),
            }
          end

          break_line

          _(Chara) {
            extend SpriteTarget
            attribute image_source: image(item.chara_name), chara_index: item.chara_index,
                      width: 1.0,
                      margin: const_box(-96-32-32-16, 0, 0, -8)
          }

          break_line

          _(CabinetInverse) {
            attribute width: 1.0, height: 70,
                      vertical_alignment: Alignment::BOTTOM,
                      margin: const_box(-70-30, 8, 0, 8)
            item.states.each do |id|
              next unless state = db_state[id]
              _(Icon) {
                attribute icon_index: state.icon_index
              } if state.icon_index != 0
            end
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
            attribute width: 0.5, height: 2,
                      background: Color.Black,
                      gauge: Color.Crimson,
                      margin: const_box(20, 2, 0, 0),
                      rate: item.max_hp != 0 ? item.hp.to_f / item.max_hp : 0
          }
          _(Gauge) {
            attribute width: 1.0, height: 2,
                      background: Color.Black,
                      gauge: Color.RoyalBlue,
                      margin: const_box(20, 0, 0, 2),
                      rate: item.max_mp != 0 ? item.mp.to_f / item.max_mp : 0
          }
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 0.5,
                      margin: const_box(3-20, 2, 0, 0),
                      caption: "HP",
                      value: item.hp
          }
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3-20, 0, 0, 2),
                      caption: "MP",
                      value: item.mp
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 0.5,
                      margin: const_box(-3, 2, 0, 0),
                      caption: "Max",
                      underline: Color.White,
                      underline_offset: -2,
                      value: item.max_hp
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(-3, 0, 0, 2),
                      caption: "Max",
                      underline: Color.White,
                      underline_offset: -2,
                      value: item.max_mp
          }

          # Basic params
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:attack),
                      value: "#{item.attack_raw}%+d" % item.attack_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:defence),
                      value: "#{item.defence_raw}%+d" % item.defence_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:magic),
                      value: "#{item.magic_raw}%+d" % item.magic_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:footwork),
                      value: "#{item.footwork_raw}%+d" % item.footwork_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:accuracy),
                      value: "#{item.accuracy_raw}%+d" % item.accuracy_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0, 0, 0),
                      caption: message.text(:evasion),
                      value: "#{item.evasion_raw}%+d" % item.evasion_equip,
                      underline: Color.White,
                      underline_offset: -1
          }
          _(CaptionedItem) {
            extend Underline
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(3, 0),
                      caption: message.text(:luck),
                      value: "#{item.luck - item.luck_equip}%+d" % item.luck_equip,
                      underline: Color.White,
                      underline_offset: -1
          }

          # Elements
          _(Tile, 36, element_size) {
            attribute width: 1.0

          elements.each.with_index do |element_name, element_id|
            next unless element_name && element_name.empty?.!
            _(CaptionedItem) {
              res = item.element_resistance(element_id)
              attribute width: 30+6,
                        icon_index: element_icons[element_id],
                        icon_size: element_size,
                        margin: const_box(0, 1),
                        value: res,
                        vertical_alignment: Alignment::BOTTOM,
                        font_size: 18,
                        font_bold: res < 0,
                        font_color: res < 0 ? Color.Red : Color.White,
                        font_out_color: res > 0 ? Color.Blue : Color.Black
            }
          end
          }

          break_line

          _(Separator) { attribute  height: 1, width: 1.0, margin: const_box(3, 0), separate_color: Color.White }

          # States
          _(Label) {
            apply_font(font_state)
            attribute height: element_size,
                      width: 1.0,
                      margin: const_box(0, 0, -20, 0),
                      vertical_alignment: Alignment::BOTTOM
            if item.immuned_states.size < 5
              attribute horizontal_alignment: Alignment::CENTER,
                        text: message.text(:immuned)
            end
          }
          if item.immuned_states.empty?
            _(Empty) { attribute height: element_size }
          else
            _(Lineup) {
              attribute min_width: 1.0, height: element_size
              item.immuned_states.each do |state_id|
                next unless state = db_state[state_id]
                _(Icon) {
                  attribute icon_index: state.icon_index,
                            margin: const_box(0, 2, 0, 1),
                            width: element_size, height: element_size
                }
              end
            }
            # 耐性上位三種を表示するバージョン
            # item.proofed_states.first(3).each.with_index do |state, state_index|
            #   _(CaptionedItem) {
            #     res = item.state_resistance(state.id)
            #     attribute icon_index: state.icon_index,
            #               width: 30+4,
            #               icon_size: element_size,
            #               margin: const_box(0, 2),
            #               value: res,
            #               vertical_alignment: Alignment::BOTTOM,
            #               font_size: 18,
            #               font_bold: res < 0,
            #               font_color: res < 0 ? Color.Red : Color.White,
            #               font_out_color: res > 0 ? Color.Blue : Color.Black
            #   }
            # end
          end

          break_line

          # Exp
          _(Separator) { attribute  height: 1, width: 1.0, margin: const_box(3, 0), separate_color: Color.White }

          _(Gauge) {
            attribute width: 1.0, height: 2,
                      background: const_color(0x20, 0x20, 0x20),
                      gauge: proc_gradiation,
                      margin: const_box(18, 0, 0, 0),
                      rate: item.exp ? (item.exp.to_f / item.exp_next) : 0
          }
          _(CaptionedItem) {
            apply_font(font_exp)
            attribute width: 1.0,
                      margin: const_box(4-18-2, 0, -3, 0),
                      caption: "Exp",
                      value: item.exp || "-"
          }
          _(CaptionedItem) {
            apply_font(font_exp)
            attribute width: 1.0,
                      caption: "Next",
                      value: item.exp_next == Float::INFINITY ? "‐" : item.exp_next || "-"

          }
        }
                }
    }
}

=begin
  戦闘画面の敵情報
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(Graphics.height-160, 150, 5, 150),
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::TOP

  TargetInfo = Struct.new(:icon_index, :label, :hit_rate)
  context = Struct.new(:info_name, :info_dmg, :info_mhp, :info_rate, :info_action_name, :info_action_target, :info_states, :info_hits, :info_hit, :info_action_elements, :info_actions).new("b.ジェムスパイダー", 30, 50, 30.0/50, "超スピリットアーツ", [], [1,10, [1,10],[2,-3],[5,1]], [], 100, [1,4,5], [])
  ActionInfo = Struct.new(:name, :targets, :elements)

  context.info_action_target = [
    TargetInfo.new(25, "", rand(101)),
    TargetInfo.new(25, "", rand(101)),
  ]
  context.info_hits = [TargetInfo.new(9, "a", 100)]*3

  context.info_actions[0] = ActionInfo.new("超スピリットアーツ", context.info_action_target,  context.info_action_elements)
  context.info_actions[1] = ActionInfo.new("エレメンタリール", context.info_action_target,  context.info_action_elements)
end

message = Application.language.load_message(:battle)
self.add_callback(:finalized) {
  Application.language.release_message(:battle)
}

database = Application.database
db_states = database.states

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

buff_icons = [
  32,
  33,
  34,
  35,
  36,
  474,
  430,
  38,
]
debuff_icons = [
  48,
  49,
  50,
  51,
  52,
  181,
  3,
  54,
]

_(Decorator) {
  attribute width: 1.0, height: 1.0,
            margin: const_box(0, 0, 20, 0),
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::BOTTOM

_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW).play_speed = 2
  animation(:out, &Constant::Animation::CLOSE_WINDOW).play_speed = 2

  attribute name: :command_info_window,
            width: 0.7, height: Size::AUTO,
            viewport: viewport,
            openness: 0

  _(Lineup) {
    attribute width: 1.0, height: Size::AUTO,
              horizontal_alignment: Alignment::RIGHT,
              orientation: Orientation::VERTICAL

    # 名前欄
    _(Canvas) {
      attribute width: 1.0,
                horizontal_alignment: Alignment::RIGHT


      _(Label) {
        attribute text: binding { context.info_name },
                  width: 1.0,
                  font_size: Language::Locale.half? ? 22 : binding(nil, proc {|v|
                    if v.nil? || v.size <= 10
                      22
                    elsif v.size <= 11
                      20
                    elsif v.size <= 12
                      18
                    else
                      16
                    end
                  }) { context.info_name },
      }
      _(Label) {
        attribute text: binding(nil, proc {|v|
                      v ? "#{message.text(:command_info_hit)}#{v}%" : ""
                    }) { context.info_hit },
                  # margin: const_box(0, 0, 0, 10),
                  height: 22,
                  vertical_alignment: Alignment::BOTTOM,
                  font_size: 18
      }
    }

    # 全体への命中率
    _(Cabinet) {
      attribute width: 1.0, height: Size::AUTO,
                margin: const_box(5, 0),
                visibility: binding(Visibility::COLLAPSED, proc {|v| v && v.empty?.! ? Visibility::VISIBLE : Visibility::COLLAPSED }) { context.info_hits },
                horizontal_alignment: Alignment::LEFT,
                vertical_alignment: Alignment::TOP,
                orientation: Orientation::HORIZONTAL,
                items: binding { context.info_hits },
                item_template: proc {|item, item_index|
      _(CaptionedItem) {
        attribute height: 24,
                  font_size: 20,
                  vertical_alignment: Alignment::BOTTOM,
                  margin: const_box(0, 0, 0, 5),
                  icon_offset: -5,
                  unit_offset: 0,
                  icon_index: item.icon_index,
                  value: item.label,
                  unit: "#{item.hit_rate}%"
      }
                }
    }

    # ステート、ダメージ
    _(Lineup) {
      attribute width: 1.0, height: Size::AUTO,
                visibility: binding(Visibility::VISIBLE, proc {|v| v.nil? ? Visibility::COLLAPSED : Visibility::VISIBLE }) { context.info_mhp },
                horizontal_alignment: Alignment::LEFT,
                vertical_alignment: Alignment::BOTTOM,
                orientation: Orientation::HORIZONTAL,
                items: binding { context.info_states },
                item_template: proc {|item, item_index|
                  case item
                  when Array
                    # 強化・弱体化
        buff_id, count = item
        if count > 0
          # buff
          _(Icon) {
            attribute icon_index: buff_icons[buff_id] || 0,
                      margin: const_box(0, 0, 2)
          }
        elsif count < 0
          # debuff
          _(Icon) {
            attribute icon_index: debuff_icons[buff_id] || 0,
                      margin: const_box(0, 0, 2)
          }
        end
        if count != 0
          _(Label) {
            attribute text: count.abs,
                      font_size: 18,
                      font_out_color: count > 0 ? Color.Blue : Color.Red,
                      margin: const_box(0, 0, 0, -3)
          }
        end
                  else
                    # ステート
        state = db_states[item]
        _(Icon) {
          attribute icon_index: state && state.icon_index || 0,
                    margin: const_box(0, 0, 2)
        } if (state && state.icon_index || 0) != 0
                  end
                }
      _(CaptionedItem) {
        attribute margin: const_box(0, 10, 0, 7),
                  item_index: -1,
                  font_size: 20,
                  height: 24,
                  value: message.text(:command_info_label_damage),
                  unit: binding { context.info_dmg }
      }
    }

    # ダメージゲージ
    _(Gauge) {
      rate_obj = BindingObject.new(self, nil, proc {|v|
        if (mhp = unbox(context.info_mhp)) && mhp != 0
          unbox(context.info_dmg).to_f / mhp
        else
          0
        end
      })
      rate_obj.subscribe(context.info_mhp)
      rate_obj.subscribe(context.info_dmg)

      color_obj = BindingObject.new(self, Color.Red, proc {|v|
        if (mhp = unbox(context.info_mhp)) && mhp != 0
          if unbox(context.info_dmg).to_f / mhp < 0.7
            Color.Red
          else
            Color.GreenYellow
          end
        else
          Color.Grey
        end
      })
      color_obj.subscribe(context.info_mhp)
      color_obj.subscribe(context.info_dmg)

      attribute width: 1.0, height: 4,
                visibility: binding(Visibility::VISIBLE, proc {|v| v.nil? ? Visibility::COLLAPSED : Visibility::VISIBLE }) { context.info_mhp },
                margin: const_box(0, 10, 0),
                background: color_obj,
                gauge: Color.Black,
                rate: rate_obj
    }

    # 予定の攻撃対象
    _(Cabinet) {
      def self.construct_children(items)
        clear_break_lines
        super
      end

      attribute width: 1.0,
                visibility: binding(Visibility::VISIBLE, proc {|v| v.nil? ? Visibility::COLLAPSED : Visibility::VISIBLE }) { context.info_mhp },
                margin: const_box(0, 10, 10),
                horizontal_alignment: Alignment::CENTER,
                vertical_alignment: Alignment::CENTER,
                content_alignment: Alignment::BOTTOM,
                orientation: Orientation::HORIZONTAL,
                items: binding { context.info_actions },
                item_template: proc {|item, item_index|
      # スキル名
      _(Label) {
        attribute text: item.name || message.text(:command_info_unknown_skill),
                  height: 24,
                  margin: const_box(10, 0, 0),
                  vertical_alignment: Alignment::CENTER,
                  font_size: 20
      }
      # スキル属性
      _(Lineup) {
        attribute height: 24,
                  items: item.elements,
                  item_template: proc {|item, item_index|
          _(Icon) {
            attribute icon_index: element_icons[item],
                      margin: const_box(0, -2)
          }
                  }
      }
      # 対象を示す記号
      _(Label) {
        attribute text: ">>",
                  visibility:
                  item.targets && item.targets.empty?.! ? Visibility::VISIBLE : Visibility::COLLAPSED,
                  margin: const_box(0,2)
      }
      # スキルの対象
      _(Lineup) {
        action_name = item.name
        attribute items: item.targets,
                  height: 24,
                  item_template: proc {|item, item_index|
            _(CaptionedItem) {
              attribute icon_index: item.icon_index,
                        font_size: 18,
                        icon_offset: -3,
                        unit_offset: -3,
                        vertical_alignment: Alignment::BOTTOM,
                        value: action_name ? item.hit_rate : "?",
                        unit: "%"
            }
          }
      }
      break_line
                }
=begin
      # スキル名
      _(Label) {
        attribute text: binding("", proc {|v| v || message.text(:command_info_unknown_skill) }) { context.info_action_name },
                  height: 24,
                  vertical_alignment: Alignment::CENTER,
                  font_size: 20
      }
      # スキル属性
      _(Lineup) {
        attribute height: 24,
                  items: binding { context.info_action_elements },
                  item_template: proc {|item, item_index|
          _(Icon) {
            attribute icon_index: element_icons[item],
                      margin: const_box(0, -2)
          }
                  }
      }
      # 対象を示す記号
      _(Label) {
        attribute text: ">>",
                  visibility: binding(Visibility::COLLAPSED, proc {|v|
          v && v.empty?.! ? Visibility::VISIBLE : Visibility::COLLAPSED }) { context.info_action_target },
                  margin: const_box(0,2)
      }
      # スキルの対象
      _(Lineup) {
        attribute items: binding { context.info_action_target },
                  height: 24,
                  item_template: proc {|item, item_index|
            _(CaptionedItem) {
              attribute icon_index: item.icon_index,
                        font_size: 18,
                        icon_offset: -3,
                        unit_offset: -3,
                        vertical_alignment: Alignment::BOTTOM,
                        value: unbox(context.info_action_name) ? item.hit_rate : "?",
                        unit: "%"
            }
          }
      }
=end
    }
  }
}
}

if debug?
  self.add_callback(:layouted) {
    self.view.play_animation(:command_info_window, :in)
  }
end


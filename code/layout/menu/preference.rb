=begin
  設定画面
=end

if debug? && context.!

  context = Struct.new(:languages, :current_language, :system_properties, :pad_assignments, :notice, :volume_target, :volumes, :version).new
  LangData = Struct.new(:id, :label)
  context.languages = [
    LangData.new(:ja_jp, "日本語"),
    LangData.new(:en_us, "English"),
  ]
  context.current_language = :ja_jp
  context.system_properties = {
    system_music: rand(2) == 0,
    system_sound: rand(2) == 0,
    system_fullscreen: rand(2) == 0,
    system_vsync: rand(2) == 0,
  }
  context.pad_assignments = {
    decide: 10,
    cancel: 11,
    dash: 12,
    sneak: 13,
    option: nil,
    config: nil,
    quick_save: nil,
    quick_load: nil,
  }
  context.notice = "通知です。"
  context.volume_target = :bgm
  context.volumes = {
    bgm: rand(101),
    me:  rand(101),
    bgs: rand(101),
    se:  rand(101),
  }
  context.version = "2001-02-14"

end

font_label = ::Font.new.tap {|font|
  font.size = 22
}
font_label_enabled = font_label.clone.tap {|font|
  font.out_color = Color.MidnightBlue
}
font_label_selected = font_label.clone.tap {|font|
  font.out_color = Color.Blue
}
font_item = ::Font.new.tap {|font|
  font.size = 20
}
font_item_disabled = font_item.clone.tap {|font|
  font.color = Color.Grey
}
font_version = ::Font.new.tap {|font|
  font.size = 20
  font.color = Color.LightGrey
}

separator_margin = 5


message = Application.language.load_message(:preference)
self.add_callback(:finalized) {
  Application.language.release_message(:preference)
}


_(Canvas) {
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER


_(Window) {
  attribute width: 1.0, height: 1.0,
            # horizontal_alignment: Alignment::CENTER,
            padding: const_box(10, 10, 10, 10)

  _(Lineup) {
    extend Cursor
    attribute name: :menu,
              orientation: Orientation::VERTICAL

    # 言語設定
    _(Lineup) {
      attribute name: :lang,
                width: 1.0,
                padding: const_box(7, 5)
      _(Label) {
        apply_font(font_label)
        attribute text: message.text(:language_label)
      }
      _(Decorator) {
        attribute width: 1.0,
        horizontal_alignment: binding(nil, proc {|v| v && v.size >= 4 ? Alignment::RIGHT : Alignment::CENTER }) { context.languages }
      _(Lineup) {
        extend SpriteTarget
        extend Drawable
        extend Cursor
        extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
        extend ScrollBar
        attribute name: :languages,
                  max_width: 1.0,
                  scroll_direction: Orientation::HORIZONTAL,
                  scroll_scale: 30,
                  horizontal_alignment: Alignment::LEFT,
                  margin: const_box(0, 0, 0, 30),
                  items: binding { context.languages },
                  item_template: proc {|item, item_index|
          _(Label) {

            obj_language = binding { context.current_language }.bind(self, :language)
            proc_apply_font = proc {|c, name, old_value|
              case name
              when :language
                if obj_language.unbox == item.id
                  # apply_font(font_label_selected)
                  c.font_out_color = font_label_selected.out_color
                else
                  # apply_font(font_label)
                  c.font_out_color = font_label.out_color
                end
              end
            }
            add_callback(:binding_value_changed, &proc_apply_font)
            apply_font(font_label.clone)
            proc_apply_font.call(self, :language)

            attribute text: item.label,
                      font_name: Language::Locale.default_font(item.id) || Application.instance.font_system_default,
                      # margin: const_box(1),
                      padding: const_box(4, 7, 4, 10)
          }
                  }
      }
      }
    }

    _(Separator) {
      extend Unselectable
      attribute height: 3,
                margin: const_box(separator_margin, 0),
                padding: const_box(1),
                separate_color: Color.White,
                border_color: Color.Black
    }

    # 音量設定
    _(Lineup) {
      attribute name: :volumes,
                width: 1.0,
                padding: const_box(5)
      _(Label) {
        apply_font(font_label)
        attribute text: message.text(:volume_label)
      }

      _(Cabinet) {
        extend Cursor
        attribute name: :volume_list,
                  width: 1.0,
                  margin: const_box(5, -10, 0, -2),
                  horizontal_alignment: Alignment::CENTER,
                  orientation: Orientation::HORIZONTAL


        { bgm: :system_music, me: :system_music, bgs: :system_sound, se: :system_sound }.each {|key, value|
        _(Lineup) {
          attribute name: key,
                    vertical_alignment: Alignment::CENTER,
                    margin: const_box(0, -2, 0, 0),
                    padding: const_box(0, 8, 5)

            proc_apply_font = proc {|c, name, old_value|
              case name
              when :check
                if unbox(context.system_properties[value])
                  c.apply_font(font_item)
                else
                  c.apply_font(font_item_disabled)
                end
              end
            }

          _(Label) {
            obj_check = binding { context.system_properties[value] }.bind(self, :check)
            add_callback(:binding_value_changed, &proc_apply_font)
            proc_apply_font.call(self, :check)
            # apply_font(font_item)

            attribute text: message.text(:"volume_#{key}")
          }
          _(Gauge) {
            attribute width: 200+2*1, height: 2+2*1,
                      independent: true,
                      margin: const_box(30, 2, 2),
                      padding: const_box(1),
                      orientation: Orientation::HORIZONTAL,
                      background: Color.Black,
                      gauge: binding(nil, proc {|v| v && Color.Red || Color.Grey }) { context.system_properties[value] },
                      rate: binding(nil, proc {|v| v && v / 100.0 || 0 }) { context.volumes[key] }
          }

          _(Label) {
            obj_check = binding { context.system_properties[value] }.bind(self, :check)
            add_callback(:binding_value_changed, &proc_apply_font)
            # apply_font(font_item)
            proc_apply_font.call(self, :check)

            attribute text: binding(nil, proc {|v| v && "%3d" % v }) { context.volumes[key] },
                      independent: true,
                      margin: const_box(0, 0, 0, -10)
          }
        }
        }

      }
    }

    _(Separator) {
      extend Unselectable
      attribute height: 3,
                margin: const_box(separator_margin, 0),
                padding: const_box(1),
                separate_color: Color.White,
                border_color: Color.Black
    }

    # キーコンフィグ
    _(Lineup) {
      attribute name: :assignments,
                width: 1.0,
                padding: const_box(5)
      _(Label) {
        apply_font(font_label)
        attribute text: message.text(:assign_label)
      }
      _(Decorator) {
        attribute width: 1.0,
                  horizontal_alignment: Alignment::RIGHT
      _(Lineup) {
        extend SpriteTarget
        extend Drawable
        extend Cursor
        extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
        extend ScrollBar
        attribute name: :pad_list,
                  max_width: 1.0,
                  scroll_direction: Orientation::HORIZONTAL,
                  scroll_scale: 30,
                  bar_color: Color.LightGrey,
                  horizontal_alignment: Alignment::LEFT,
                  padding: const_box(0, 0, 5, 0),
                  margin: const_box(0, 0, 0, 20)
        ([:decide, :cancel, :dash, :sneak, :option, :config, :quick_save, :quick_load]).each do |key|
          _(Label) {
            apply_font(font_item)
            attribute name: key,
                      independent: true,
                      text: binding(nil, proc {|v| "#{message.text(:"assign_#{key}")}:#{v||message.text(:assign_unassigned)}" }) { context.pad_assignments[key] },
                      margin: const_box(1, -1),
                      padding: const_box(2, 7, 2, 9)
          }
        end
      }
      }
    }

    _(Separator) {
      extend Unselectable
      attribute height: 3,
                margin: const_box(separator_margin, 0),
                padding: const_box(1),
                separate_color: Color.White,
                border_color: Color.Black
    }

    # システム設定
    _(Lineup) {
      extend Unselectable
      attribute orientation: Orientation::HORIZONTAL,
                vertical_alignment: Alignment::BOTTOM
      _(Label) {
        attribute text: message.text(:system_label),
                  margin: const_box(10, 0, 10),
                  font_size: 26
      }
      _(Label) {
        attribute text: message.text(:system_note),
                  margin: const_box(10, 0, 10),
                  font_size: 20
      }
    }

    [:system_music, :system_sound, :system_fullscreen, :system_vsync].each do |key|
      _(Lineup) {
        attribute name: key,
                  vertical_alignment: Alignment::CENTER

        _(Icon) {
          attribute width: 24, height: 24,
                    image_source: load_image("Graphics/UI/Preference/check"),
                    margin: const_box(-2, -2, -2, 10-2),
                    independent: true,
                    icon_index: binding(nil, proc {|v| v && 0 || 1 }) { context.system_properties[key] }
        }
        _(Label) {
          obj_check = binding { context.system_properties[key] }.bind(self, :check)
          proc_apply_font = proc {|c, name, old_value|
            case name
            when :check
              if obj_check.unbox
                apply_font(font_label_enabled)
              else
                apply_font(font_label)
              end
            end
          }
          add_callback(:binding_value_changed, &proc_apply_font)
          proc_apply_font.call(nil, :check)
          # apply_font(font_label)
          attribute text: message.text(key),
                    # margin: const_box(0, 0, 0, 20),
                    padding: const_box(2, 6)
        }
      }
    end

    _(Separator) {
      extend Unselectable
      attribute height: 3,
                margin: const_box(separator_margin + 10, 0, separator_margin+5),
                padding: const_box(1),
                separate_color: Color.White,
                border_color: Color.Black
    }

    # ゲームを終了
    _(Label) {
      apply_font(font_label)
      attribute name: :shutdown,
                text: message.text(:shutdown_game),
                padding: const_box(2, 6)
    }

    # 設定画面を終了
    _(Label) {
      apply_font(font_label)
      attribute name: :quit,
                text: message.text(:quit_config),
                padding: const_box(2, 6)
    }

    # バージョン情報
    _(Label) {
      extend Unselectable
      apply_font(font_version)
      attribute text: binding(nil, proc {|v| "(build.#{v})" }) { context.version },
                width: 1.0,
                margin: const_box(-font_version.size, 0, 0, 0),
                horizontal_alignment: Alignment::RIGHT
    }
  }

}

# Pad設定画面
_(Window) {
  extend Animatable
  extend Focusable
  self.window.z = 102

  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)
  self.focused = proc {|control|
    control.play_animation(:in)
  }
  self.unfocused = proc {|control|
    control.play_animation(:out)
  }
  self.operation_instructed = proc {|control, code|
    pop_focus if code != Operation::MOVE_POSITION
  }
  attribute name: :pad_window,
            padding: const_box(6, 10),
            openness: 0

  _(Lineup) {
    attribute orientation: Orientation::VERTICAL
    _(Label) {
      attribute text: message.text(:notice_pad)
    }
    _(Label) {
      apply_font(font_item)
      attribute text: message.text(:notice_pad2),
                margin: const_box(5, 0, 0)
    }
  }
}

# 通知画面
_(Window) {
  extend Animatable
  extend Focusable
  self.window.z = 102

  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)
  self.focused = proc {|control|
    control.play_animation(:in)
  }
  self.unfocused = proc {|control|
    control.play_animation(:out)
  }
  self.operation_instructed = proc {|control, code|
    pop_focus if code != Operation::MOVE_POSITION
  }
  attribute name: :notice_window,
            padding: const_box(6, 10),
            openness: 0

  _(Label) {
    attribute text: binding { context.notice }
  }
}


# 音量調整画面
_(Window) {
  extend Animatable
  self.window.z = 102

  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)
  attribute name: :volume_window,
            padding: const_box(6, 10),
            openness: 0

  _(Lineup) {
    attribute horizontal_alignment: Alignment::CENTER,
              orientation: Orientation::VERTICAL

    _(Label) {
      attribute text: binding(nil, proc {|v| v && message.text(:"volume_#{v}_label") }) { context.volume_target }
    }

    _(Dial) {
      attribute name: :volume_dial,
                horizontal_alignment: Alignment::CENTER,
                number: 0,
                max_number: 100,
                loop: true,
                margin: const_box(5, 0, 0),
                padding: const_box(2, 2, 2, 4)
    }
  }
}

}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:menu)
    # self.view.push_focus(:pad_list)
    # self.view.push_focus(:pad_window)
    # self.view.push_focus(:volume_list)
    # self.view.push_focus(:notice_window)
    # self.view.control(:pad_window).openness = 0xff
    root.view.play_animation(:volume_window, :in).finisher {
      self.view.push_focus(:volume_dial)
    }
  }
end

=begin
  セーブデータの管理画面
  セーブとロードで同じ画面レイアウトを共有する
=end

if debug?
  context = Struct.new(:start_index, :records, :actors, :image, :map_name, :dialog, :notice).new
  RecordItem = Struct.new(:level, :playing_time, :label)
  ActorItem = Struct.new(:level, :hp, :mp, :exp, :face_name, :face_index)
  Dialog = Struct.new(:message, :choices)
  context.start_index = 0
  context.map_name = "エルクの村-室内"
  context.records = [
    :back_to_title,
    # RecordItem.new("?", 0, "エルクの村-室内"),
    RecordItem.new("?", 0, "Outskirts of Erlcian Village"),
    nil,
    RecordItem.new(10, 100*60*60, "マナンの遺跡"),
  ] + ([
    RecordItem.new(rand(10)+3, rand(100*60*60), "ユベシア雪洞"),
  ] * 3) + [
    nil,
    :new_record,
    :next_page,
  ] 
  context.actors = [
    ActorItem.new(21, 123, 999, 123456789, "Actor1", 1),
    ActorItem.new(3, 12, 2, 325, "Actor1", 4),
    ActorItem.new(88, 888, 888, 8888888888, "Actor1", 3),
  ]
  context.image = :new_game
  context.dialog = Dialog.new("セーブしますか？", ["はい", "いいえ"])
  context.notice = "テストメッセージです。"
end

separator = 240

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

_(Canvas) {

  # データの一覧
  _(Window, 0, 0) {
    attribute width: separator, height: 1.0
    _(Cabinet) {
      extend Cursor
      extend Scrollable::CustomScroll
      if debug
        add_callback(:decided) {
         self.push_focus(:dialog_list)
        }
      end
      attribute width: 1.0, height: 1.0,
                name: :records,
                margin: const_box(-2, 0),
                orientation: Orientation::HORIZONTAL,
                horizontal_alignment: Alignment::LEFT,
                vertical_alignment: Alignment::TOP,
                content_alignment: Alignment::LEFT,
                items: binding { context.records },
                item_template: proc {|item, item_index|
        i = (item_index + unbox(context.start_index))
        case item
        when :separator
          _(Separator) {
            extend Unselectable
            attribute width: 1.0, height: 3,
                      margin: const_box(3, 15),
                      padding: const_box(1),
                      separate_color: Color.White,
                      border_color: Color.Black
          }
        when :new_record
          _(Label) {
            attribute text: "%02d. #{message.text(:save_newrecord)}" % i,
                      width: 1.0, height: 54,
                      font_size: 20,
                      padding: const_box(6, 20)
          }
        when :next_page
          _(Decorator) {
            extend SelectDelegation
            _(Lineup) {
              extend Cursor
              extend Scrollable::CustomScroll
              attribute width: 1.0, height: 54,
                        name: :next_page,
                        horizontal_alignment: Alignment::RIGHT,
                        orientation: Orientation::HORIZONTAL
              _(Label) {
                attribute text: message.text(:save_prev_page),
                          horizontal_alignment: Alignment::LEFT,
                          width: 0.5, height: 1.0,
                          font_size: 20,
                          padding: const_box(3, 20)
              }
              _(Label) {
                attribute text: message.text(:save_next_page),
                          horizontal_alignment: Alignment::RIGHT,
                          width: 1.0, height: 1.0,
                          font_size: 20,
                          padding: const_box(3, 20)
              }
            }
          }
        when :back_to_title
          _(Label) {
            extend Underline
            attribute text: message.text(:discard_journal),
                      width: 1.0,
                      font_size: 20,
                      margin: const_box(8, 0, 4),
                      padding: const_box(10, 20, 10, 50)
          }
        when nil
          _(Canvas) {
            attribute padding: const_box(6, 20)
            _(CaptionedItem) {
              attribute caption: "%02d. Lv." % i,
                        width: 1.0,
                        value: "--",
                        unit_offset: 36,
                        unit: "--:--:--",
                        font_size: 20
            }
            _(Label) {
              attribute text: message.text(:save_nodata),
                        width: 1.0, margin: const_box(20, -300, 0, 30),
                        font_size: 20
            }
          }
        when :new_game
          _(Canvas) {
            attribute padding: const_box(6, 20)
            _(CaptionedItem) {
              attribute caption: "%02d. Lv." % i,
                        width: 1.0,
                        value: "?",
                        unit_offset: 36,
                        unit: "??:??:??",
                        font_size: 20
            }
            _(Label) {
              attribute text: message.text(:save_entrypoint),
                        width: 1.0, margin: const_box(20, -300, 0, 30),
                        font_size: 20
            }
          }
        else
          _(Canvas) {
            attribute padding: const_box(6, 20)
            _(CaptionedItem) {
              attribute caption: sprintf("%02d. Lv. %s", i, item.level.to_s),
                        width: 1.0,
                        # value: item.level,
                        # unit_offset: 36,
                        unit: item.playing_time > 0 ? Itefu::Utility::Time.second_to_hms(item.playing_time) : "--:--:--",
                        font_size: 20
            }
            _(Label) {
              label = item.label
              case label
              when Time
                label = label.strftime(message.text(:save_backup_timestamp))
              end
              attribute text: label,
                        width: 1.0,
                        margin: const_box(20, -300, 0, 30),
                        font_size: 20
            }
          }
        end
      }
    }
  }

  # データの詳細
  _(Window, 0, 0) {
    attribute width: Graphics.width - separator, height: 1.0,
              margin: const_box(0, 0, 0, separator)
    _(Lineup) {
      attribute width: 1.0, height: 1.0,
                orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::CENTER

      _(Image) {
        self.auto_release = true
        attribute image_source: binding(nil, proc {|v|
                      case v
                      when String
                        load_image(v)
                      when :new_game
                        load_image("#{Filename::Graphics::Ui::PATH_MENU}/snapshot000")
                      when :backup
                        load_image("#{Filename::Graphics::Ui::PATH_MENU}/snapshot_backup")
                      else
                        release_image
                      end
                    }) { context.image },
                  # margin: const_box(24, 0, 30, 0),
                  margin: const_box(24, 0, 0, 0),
                  width: 320, height: 240
      }

      _(Label) {
        attribute text: binding(nil, proc {|v|
                    case v
                    when :new_game
                      message.text(:save_entrypoint)
                    when :new_game_benefit
                      message.text(:save_with_benefit)
                    else
                      v
                    end
                  }) { context.map_name },
                  font_size: 20,
                  margin: const_box(2, 0, 18)
      }

      _(Lineup) {
        attribute orientation: Orientation::HORIZONTAL,
                  items: binding { context.actors },
                  item_template: proc {|item, item_index|
         _(Cabinet){
            attribute orientation: Orientation::HORIZONTAL,
                      margin: const_box(0, 7),
                      width: 96
            _(Face) {
              attribute image_source: image(item.face_name),
                        face_index: item.face_index
            }

            break_line

            _(Label) {
              attribute text: String === item.level ? "Lv. #{item.level}" : "Lv. %2d" % item.level,
                        width: 1.0,
                        font_size: 18
            }

            break_line

            _(CaptionedItem) {
              attribute caption: "HP",
                        value: item.hp,
                        width: 0.5,
                        margin: const_box(0, 2, 0, 0),
                        font_size: 18
            }
            _(CaptionedItem) {
              attribute caption: "MP",
                        value: item.mp,
                        width: 1.0,
                        margin: const_box(0, 0, 0, 2),
                        font_size: 18
            }

            break_line

            _(CaptionedItem) {
              attribute caption: "Exp",
                        value: item.exp,
                        width: 1.0,
                        font_size: 18
            }
          }
        }
      }
    }
  }

  # Notification
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::CENTER
    _(Importer, "notice", context) {
      child.max_width = 0.8
    }
  }

  # 確認ダイアログ
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::CENTER
    _(Importer, "dialog", context.dialog) {
    }
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:records)
    self.view.control(:notice_window).openness = 0xff
  }
end


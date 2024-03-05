=begin
  キャラクター選択ダイアログ
=end

if debug? && context.nil?
  imported = true
  context = Struct.new(:message, :actors).new
  context.message = "だれに使いますか"

  ActorData = Struct.new(:chara_name, :chara_index, :hp, :mhp, :mp, :mmp, :hp_rate, :mp_rate, :exp, :exp_rate, :states)
  context.actors = [
    ActorData.new("Actor1", 1, 10, 10, 5, 5, 0.5, 0.5, 99999, 1.0, [1,2,3,4,5]),
    ActorData.new("Actor1", 2, 57, 123, 20, 888, 1.0, 0.3, 0, 0.0, []),
    ActorData.new("Actor1", 3, 10, 327, 0, 20, 0.7, 0.0, 1234, 0.45, []),
  ]
end

font_item = ::Font.new.tap {|font|
  font.size = 19
}
anime_frames = []

# proc_gradiation = proc {|control, bmp, x, y, w, h|
#   if w > 1
#     bmp.gradient_fill_rect(x, y, w, h, Color.White, Color.GoldenRod)
#   else
#     control.draw_background_color(bmp, x, y, w, h, Color.GoldenRod)
#   end
# }


_(Window, 0, 0) {
  extend Animatable
  animation(:in, &Constant::Animation::OPEN_WINDOW)
  animation(:out, &Constant::Animation::CLOSE_WINDOW)

  attribute horizontal_alignment: Alignment::CENTER,
            name: :dialog_chara_window,
            openness: 0

  _(Lineup) {
    # 全体を選ぶとき用のカーソル
    extend Cursor
    self.focused = proc {|control|
      root.view.play_animation(:dialog_chara_window, :in)
    }
    self.unfocused = proc {|control|
      root.view.play_animation(:dialog_chara_window, :out)
    }
    attribute name: :dialog_chara_all,
              orientation: Orientation::VERTICAL,
              horizontal_alignment: Alignment::CENTER

    _(Text) {
      extend Unselectable
      attribute item_index: 0,
                font_size: 22,
                text_word_space: -2,
                margin: const_box(0, 0, 5),
                horizontal_alignment: Alignment::RIGHT,
                text: binding { context.message }
    }

    _(Cabinet) {
      # 個々のキャラクターを選ぶとき用のカーソル
      extend Cursor
      self.focused = proc {|control|
        root.view.play_animation(:dialog_chara_window, :in)
      }
      self.unfocused = proc {|control|
        root.view.play_animation(:dialog_chara_window, :out)
      }

      # 全体選択のときのアニメーション
      self.add_callback(:select_activated) {|control|
        @activated = true
        anime_frames.each {|anime_frame| anime_frame.modify(16) }
      }
      self.add_callback(:select_deactivated) {|control|
        @activated = false
        anime_frames.each {|anime_frame| anime_frame.modify(0) }
      }
      self.add_callback(:select_canceled) {|control|
        @activated = true
        anime_frames.each {|anime_frame| anime_frame.modify(0) }
      }
      self.add_callback(:constructed_children) {|control, items|
        # 先にフォーカスオンになってから子を構築したとき
        if @activated
          anime_frames.each {|anime_frame| anime_frame.modify(16) }
        end
      }

      attribute name: :dialog_chara_list,
                unintrusivable: true,
                orientation: Orientation::HORIZONTAL,
                content_alignment: Alignment::STRETCH,
                horizontal_alignment: Alignment::CENTER,
                padding: const_box(5),
                items: binding { context.actors },
                item_template: proc {|item, item_index|
        _(Lineup) {
          attribute width: 64 + 24,
                    padding: const_box(3, 0),
                    horizontal_alignment: Alignment::CENTER,
                    orientation: Orientation::VERTICAL

          anime_frame = anime_frames[item_index] ||= observable(0)
          self.add_callback(:select_activated) {|control|
            anime_frame.modify(16)
          }
          self.add_callback(:select_deactivated) {|control|
            anime_frame.modify(0)
          }
          self.add_callback(:select_canceled) {|control|
            anime_frame.modify(0)
          }

          _(Chara) {
            attribute image_source: binding(nil, proc {|v| image(v) }) { item.chara_name },
                      chara_index: binding { item.chara_index },
                      chara_pattern: 1,
                      chara_anime_frame: binding { anime_frame }
          }

          # HP
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(2, 5),
                      independent: true,
                      caption: "HP",
                      value: BindingObject.new(self, nil, proc {|v| "#{unbox(item.hp)}/#{unbox(item.mhp)}" }).subscribe(item.hp).subscribe(item.mhp)
                      # value: binding { item.hp }
          }
          _(Gauge) {
            attribute width: 1.0, height: 2,
                      gauge: Color.Red,
                      background: Color.Black,
                      independent: true,
                      margin: const_box(-2, 5, 1),
                      rate: BindingObject.new(self, nil, proc {|v| unbox(item.hp).to_f / unbox(item.mhp) }).subscribe(item.hp).subscribe(item.mhp)
                      # rate: binding { item.hp_rate }
          }

          # MP
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(-1, 5),
                      independent: true,
                      caption: "MP",
                      value: BindingObject.new(self, nil, proc {|v| "#{unbox(item.mp)}/#{unbox(item.mmp)}" }).subscribe(item.mp).subscribe(item.mmp)
                      # value: binding { item.mp }
          }
          _(Gauge) {
            attribute width: 1.0, height: 2,
                      gauge: Color.Blue,
                      background: Color.Black,
                      margin: const_box(-2, 5, 1),
                      independent: true,
                      rate: BindingObject.new(self, nil, proc {|v| unbox(item.mp).to_f / unbox(item.mmp) }).subscribe(item.mp).subscribe(item.mmp)
                      # rate: binding { item.mp_rate }
          }

          # Exp
          _(CaptionedItem) {
            apply_font(font_item)
            attribute width: 1.0,
                      margin: const_box(-1, 5),
                      independent: true,
                      caption: "Exp",
                      value: binding { item.exp }
          }
          _(Gauge) {
            attribute width: 1.0, height: 2,
                      # gauge: proc_gradiation,
                      gauge: Color.GoldenRod,
                      background: Color.Black,
                      margin: const_box(-2, 5, 1),
                      independent: true,
                      rate: binding { item.exp_rate }
          }

          # States
          _(Cabinet) {
            attribute width: 1.0,
                      orientation: Orientation::HORIZONTAL,
                      items: binding { item.states },
                      item_template: proc {|state, state_index|
              _(Icon) {
                attribute icon_index: state,
                          width: 20, height: 20
              }
                      }
          }
        }
      }
    }
  }
}

if debug? && imported
  self.add_callback(:layouted) {
    # self.view.control(:dialog_chara_window).openness = 0xff
    # self.view.push_focus(:dialog_chara_list)
    self.view.push_focus(:dialog_chara_all)
  }
end


=begin
  ダメージ表示
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

  context = Struct.new(:value, :size, :color, :out_color, :damage_infos).new("120", 20, Color.Red, Color.Black, ["会心", "耐性<水>"])
end

font_info = ::Font.new.tap {|font|
  font.size = 20
  font.out_color = Color.Blue
}


_(Sprite) {
  # extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  extend Animatable
  animation(:in) {
    add_key  0, :opacity, 0
    add_key  7, :opacity, 0xff

    assign_target(:zoom_x, control.sprite)
    add_key  0, :zoom_x, 0.0, bezier(0.12,1,0,1)
    add_key 10, :zoom_x, 1.0

    assign_target(:zoom_y, control.sprite)
    add_key  0, :zoom_y, 0.0, bezier(0.17,1.16,0.32,1.51)
    add_key 10, :zoom_y, 1.0
  }

  animation(:in_solid) {
    assign_target(:zoom_x, control.sprite)
    add_key  0, :zoom_x, 0.0, bezier(0.12,1,0,1)
    add_key 10, :zoom_x, 1.0

    assign_target(:zoom_y, control.sprite)
    add_key  0, :zoom_y, 0.0, bezier(0.17,1.16,0.32,1.51)
    add_key 10, :zoom_y, 1.0
  }

  animation(:in_resist) {
    add_key  0, :opacity, 0
    add_key  5, :opacity, 0xff

    assign_target(:zoom_x, control.sprite)
    add_key  0, :zoom_x, 1.0
    assign_target(:zoom_y, control.sprite)
    add_key  0, :zoom_y, 1.0

    assign_target(:x, control.sprite)
    offset_mode :x, control.sprite.x
    add_key  0, :x, 5
    add_key  4, :x, 5
    add_key  7, :x, -5
    add_key 10, :x, 0
  }

  animation(:in_weak) {
    add_key  0, :opacity, 0
    add_key  5, :opacity, 0xff

    assign_target(:zoom_x, control.sprite)
    add_key  0, :zoom_x, 0.0
    add_key  3, :zoom_x, 3.5
    add_key  6, :zoom_x, 0.7
    add_key  8, :zoom_x, 1.0
    add_key 10, :zoom_x, 1.0

    assign_target(:zoom_y, control.sprite)
    add_key  0, :zoom_y, 1.2
    add_key  8, :zoom_y, 1.0
  }

  animation(:out) {
    add_key  0, :opacity, 0xff
    add_key  5, :opacity, 0
  }

  sprite.z = 255 # @todo 本当は読み込み側で他のデータとの前後関係は定義すべきだが、変更の影響を少なく敵のHPバーより上に表示するため無理やり指定している。リファクタリングするべき

  attribute name: :damage_window,
            viewport: viewport,
            # anchor_x: 0.5, anchor_y: 1.0,
            anchor_x: 0.5, anchor_y: 0.0,
            contents_creation: ContentsCreation::IF_LARGE,
            opacity: 0,
            margin: binding(nil, proc {|v|
              s = v || 0
              mb = (s <= 20) ? -3 : -1 # 小さいサイズのときはスペースを増やす
              const_box(0, 0, -1 * s + mb, 0)
            }) { context.size },
            padding: const_box(2, 7)

  # self.add_callback(:drawn) {|c|
  #   c.sprite.oy = 0
  # }

  _(Lineup) {
    attribute orientation: Orientation::HORIZONTAL,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::BOTTOM

    # 数字の中央に中央寄せするためのダミー
    # 付加情報と同じテキストを非表示で乗せることで左右の幅を均等にする
    _(Lineup) {
      attribute orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::LEFT,
                visibility: Visibility::HIDDEN,
                margin: const_box(0, 5+5, 3, 0), # 数字が謎の微ズレで綺麗に中央によらない分をついでに補正している
                items: binding { context.damage_infos },
                item_template: proc {|item, item_index|
      _(Label) {
        apply_font(font_info)
        attribute text: item
      }
                }
    }

    # ダメージの数値
    _(Label) {
      attribute text: binding { context.value },
                font_color: binding { context.color },
                font_out_color: binding { context.out_color },
                font_size: binding { context.size },
                font_bold: true
    }

    # 付加情報
    _(Lineup) {
      attribute orientation: Orientation::VERTICAL,
                horizontal_alignment: Alignment::LEFT,
                margin: const_box(0, 0, 3, 5),
                items: binding { context.damage_infos },
                item_template: proc {|item, item_index|
      _(Label) {
        apply_font(font_info)
        attribute text: item
      }
                }
    }
  }

}

if debug?
  self.add_callback(:layouted) {
    self.view.play_raw_animation(:wait, Itefu::Animation::Wait.new(30)).finisher {
      self.view.play_animation(:damage_window, :in).finisher {
        self.view.play_raw_animation(:wait, Itefu::Animation::Wait.new(30)).finisher {
          self.view.play_animation(:damage_window, :out)
        }
      }
    }
  }
end


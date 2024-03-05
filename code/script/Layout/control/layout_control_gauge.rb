=begin
  割合をグラフィカルに表示するためのゲージを描画する
=end
class Layout::Control::Gauge < Itefu::Layout::Control::Base
  include Itefu::Layout::Control::Background

  attr_bindable :orientation  # ゲージのバーが伸びる方向
  attr_bindable :gauge        # ゲージの色
  attr_bindable :rate         # [Float] ゲージを何割だけ伸ばすか[0.0-1.0]
  private :fill_padding=

  def fill_padding; true; end

  # 属性変更時の処理
  def binding_value_changed(name, old_value)
    # case name
    # end
    super
  end

  # 再整列不要の条件
  def stable_in_placement?(name)
    case name
    when :orientation, :gauge, :rate
      true
    else
      super
    end
  end

  # 再描画不要の条件
  def stable_in_appearance?(name)
    super
  end

  # 背景を描画する
  def draw_control(target)
    super # draw background

    bitmap = target.buffer
    fg = self.gauge
    rate = Itefu::Utility::Math.clamp(0.0, 1.0, self.rate||1.0)

    x = drawing_position_x
    y = drawing_position_y
    if self.orientation == Orientation::VERTICAL
      w = content_width
      h = (content_height * rate).to_i
    else
      w = (content_width * rate).to_i
      h = content_height
    end

    case fg
    when ::Color
      # 色を塗る
      draw_background_color(bitmap, x, y, w, h, fg)
    when ImageData
      # 画像を貼り付ける
      draw_background_image(bitmap, x, y, w, h, fg)
    when Proc
      # ユーザ定義の描画方法を用いる
      fg.call(self, bitmap, x, y, w, h)
    end if bitmap

  end

end

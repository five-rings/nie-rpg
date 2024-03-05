=begin
  Layoutシステム/スクロールバーを表示する
=end
module Layout::Control::ScrollBar
  extend Itefu::Layout::Control::Bindable::Extension
  include Itefu::Layout::Control::ScrollBar
  SMALLEST_BAR_SIZE = 4
  attr_bindable :bar_color     # [Color] スクロールバーの色
  attr_bindable :bar_border    # [Color] スクロールバーの境界色

private

  # スクロールバーのバーの部分を描画をカスタマイズする
  def draw_scroll_bar_content(buffer, hor, ver, w, h)
    w = w && Utility::Math.max(SMALLEST_BAR_SIZE, w) || SMALLEST_BAR_SIZE 
    h = h && Utility::Math.max(SMALLEST_BAR_SIZE, h) || SMALLEST_BAR_SIZE 
    x = drawing_position_x - padding.left + (actual_width  - w) * hor
    y = drawing_position_y - padding.top  + (actual_height - h) * ver
    buffer.fill_rect(x, y, w, h, self.bar_border || Itefu::Color.Black)
    buffer.fill_rect(x+1, y+1, w-2, h-2, self.bar_color || Itefu::Color.White)
  end

end

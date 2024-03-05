=begin
  キャプションつきの項目を一括して描画する
  実際はCompositeを組み合わせればデフォルトのコントロールでも再現できるが
  頻出パターンを簡単に描画できるようにすることでメモリ効率や描画効率の向上をはかる 
=end
class Layout::Control::CaptionedItem < Itefu::Layout::Control::Base
  include Itefu::Layout::Control::Resource
  include Itefu::Layout::Control::Drawable
  include Itefu::Layout::Control::Font

  def default_vertical_alignment; Alignment::CENTER; end

  attr_bindable :vertical_alignment
  attr_bindable :icon_index   # [Fixnum] アイコン番号
  attr_bindable :icon_size    # [Fixnum] アイコンのサイズを変更する
  attr_bindable :caption      # [String] アイコンに続けて表示される見出し
  attr_bindable :value        # [String] 任意の値
  attr_bindable :unit         # [String] 単位
  attr_bindable :icon_offset  # [Fixnum] アイコンと見出しの間の隙間のサイズ
  attr_bindable :unit_offset  # [Fixnum] 単位の手前の隙間のサイズ
  
  # アイコンアトラス上の1アイコンのサイズ
  ICON_SIZE = Itefu::Rgss3::Definition::Icon::SIZE

  # フォントが変更された際の処理
  def font_changed(name, attribute)
    super
    @text_rect = nil
  end

  # 属性変更時の処理
  def binding_value_changed(name, old_value)
    case name
    when :caption, :value, :unit
      @text_rect = nil
    when :icon_offset, :unit_offset,
         :icon_size
      @text_rect.width += (self.send(name) - old_value) if @text_rect
    end
    super
  end

  # 再整列不要の条件
  def stable_in_placement?(name)
    case name
    when :icon_index, :vertical_alignment
      true
    when :caption, :value, :unit,
         :icon_offset, :unit_offset,
         :icon_size
      # サイズが指定されているなら文字などかわっても変更されない
      (width != Size::AUTO) && (height != Size::AUTO)
    else
      super
    end
  end
    
  # 計測
  def impl_measure(available_width, available_height)
    update_text_rect
    if @text_rect
      @desired_width  = padding.width  + @text_rect.width   if width  == Size::AUTO
      @desired_height = padding.height + @text_rect.height  if height == Size::AUTO
    end
  end
  
  def inner_width
    if @text_rect
      @text_rect.width
    else
      super
    end
  end
  
  def inner_height
    if @text_rect
      @text_rect.height
    else
      super
    end
  end

  # 描画
  def draw_control(target)
    use_bitmap_applying_font(target.buffer, font) do |buffer|
      x = drawing_position_x
      y = drawing_position_y
      w = content_width
      h = content_height
      valign = self.vertical_alignment || default_vertical_alignment

      s1 = draw_icon(buffer, x, y, w, h, valign)
      s1 += (self.icon_offset || 0)

      s2 = draw_unit(buffer, x, y, w, h, valign)
      s2 += (self.unit_offset || 0)
      s2 += draw_value(buffer, x, y, w - s2, h, valign)

      draw_caption(buffer, x + s1, y, w - s1 - s2, h, valign)
    end
  end

private

  # アイコンを描画する
  def draw_icon(buffer, x, y, w, h, valign)
    return 0 unless index = self.icon_index
    @image_source ||= load_image(Itefu::Rgss3::Filename::Graphics::ICONSET)
    return 0 unless source = data(@image_source)
    
    size = self.icon_size || ICON_SIZE
    sx = Itefu::Rgss3::Definition::Icon.image_x(index)
    sy = Itefu::Rgss3::Definition::Icon.image_y(index)

    dst_rect = Itefu::Rgss3::Rect::TEMPs[0]
    dst_rect.x = x
    case valign
    when Alignment::TOP
      dst_rect.y = y
    when Alignment::BOTTOM
      dst_rect.y = y + h - size
    else
      dst_rect.y = y + (h - size) / 2
    end
    dst_rect.width = size
    dst_rect.height = size
    
    src_rect = Itefu::Rgss3::Rect::TEMPs[1]
    src_rect.x = sx
    src_rect.y = sy
    src_rect.width = src_rect.height = ICON_SIZE

    buffer.stretch_blt(dst_rect, source, src_rect)
    size
  end
  
  # 項目名のラベルを描画する
  def draw_caption(buffer, x, y, w, h, valign)
    return unless text = self.caption
    rect = buffer.rich_text_size(text)
    case valign
    when Alignment::TOP
    when Alignment::BOTTOM
      y = y + h - rect.height
    else
      y = y + (h - rect.height) / 2
    end
    buffer.draw_text(x, y, w, h, text, 0)
  end
  
  # 単位を描画する
  def draw_unit(buffer, x, y, w, h, valign)
    return 0 unless text = self.unit
    rect = buffer.rich_text_size(text)
    case valign
    when Alignment::TOP
    when Alignment::BOTTOM
      y = y + h - rect.height
    else
      y = y + (h - rect.height) / 2
    end
    buffer.draw_text(x, y, w, h, text, 2)
    rect.width
  end
  
  # 項目の値を描画する
  def draw_value(buffer, x, y, w, h, valign)
    return 0 unless text = self.value
    rect = buffer.rich_text_size(text)
    case valign
    when Alignment::TOP
    when Alignment::BOTTOM
      y = y + h - rect.height
    else
      y = y + (h - rect.height) / 2
    end
    buffer.draw_text(x, y, w, h, text, 2)
    rect.width
  end

  # 描画に必要な矩形を計算する
  def update_text_rect
    return if @text_rect
    use_bitmap_applying_font(Itefu::Rgss3::Bitmap.empty, font) do |buffer|
      ics  = self.icon_index && (self.icon_size || ICON_SIZE) || 0

      @text_rect = r1 = buffer.rich_text_size(self.caption || "")
      r2 = buffer.rich_text_size(self.value || "")
      r3 = buffer.rich_text_size(self.unit || "")

      @text_rect.height = Itefu::Utility::Math.max_from(r1.height, r2.height, r3.height, ics)
      
      @text_rect.width = ics + r1.width + r2.width + r3.width
      @text_rect.width += (self.icon_offset || 0)
      @text_rect.width += (self.unit_offset || 0)
    end
  end

end

=begin
  ウィンドウに表示されるカーソル選択と同じものを描画する
=end
class SceneGraph::Cursor < Itefu::SceneGraph::Sprite

  def initialize(parent, w, h)
    super(parent, w, h)
    @anime_counter = 0
  end

  def impl_update_actualization
    @anime_counter += 0x7
    if @anime_counter >= 0x5f
      @anime_counter = -0x5f
    end
    if @sprite
      @sprite.opacity = 0xff - @anime_counter.abs
    end
    super
  end

private

  def clear_render_target(bitmap)
    super
    return unless skin = Itefu::Rgss3::Window.default_skin

    if size_w == 32 && size_h == 32
      rect = Itefu::Rgss3::Rect::TEMP
      rect.set(64, 64, 32, 32)
      bitmap.blt(0, 0, skin, rect)
    else
      draw_variable_cursor_rect(bitmap, skin)
    end
  end

  def draw_variable_cursor_rect(bitmap, skin)
    rect = Itefu::Rgss3::Rect::TEMPs[0]
    dest = Itefu::Rgss3::Rect::TEMPs[1]

    # left-top
    rect.set(64, 64, 8, 8)
    bitmap.blt(0, 0, skin, rect)

    # left-bottom
    rect.set(64, 64+32-8, 8, 8)
    bitmap.blt(0, bitmap.height-8, skin, rect)

    # right-top
    rect.set(64+32-8, 64, 8, 8)
    bitmap.blt(bitmap.width-8, 0, skin, rect)

    # right-bottom
    rect.set(64+32-8, 64+32-8, 8, 8)
    bitmap.blt(bitmap.width-8, bitmap.height-8, skin, rect)

    # top
    rect.set(64+8, 64, 8, 8)
    dest.set(8, 0, bitmap.width-16, 8)
    bitmap.stretch_blt(dest, skin, rect)

    # bottom
    rect.set(64+8, 64+32-8, 8, 8)
    dest.set(8, bitmap.height-8, bitmap.width-16, 8)
    bitmap.stretch_blt(dest, skin, rect)

    # left
    rect.set(64, 64+8, 8, 8)
    dest.set(0, 8, 8, bitmap.height-16)
    bitmap.stretch_blt(dest, skin, rect)

    # right
    rect.set(64+32-8, 64+8, 8, 8)
    dest.set(bitmap.width-8, 8, 8, bitmap.height-16)
    bitmap.stretch_blt(dest, skin, rect)

    # center
    rect.set(64+8, 64+8, 8, 8)
    dest.set(8, 8, bitmap.width-16, bitmap.height-16)
    bitmap.stretch_blt(dest, skin, rect)
  end

end

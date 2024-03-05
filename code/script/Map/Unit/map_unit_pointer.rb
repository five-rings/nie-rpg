=begin  
  マウスの位置に表示するポインタ
=end
class Map::Unit::Pointer < Map::Unit::Base
  def default_priority; Map::Unit::Priority::POINTER; end
  COUNT_TO_KEEP_SHOWING = 30
  DEFAULT_CELL_SIZE = Itefu::Tilemap::DEFAULT_CELL_SIZE
  
  def assign_viewport(vp)
    @sprite.viewport = vp if @sprite
  end

  def on_initialize
    @sprite = Itefu::Rgss3::Sprite.new
    @sprite.z = 1
    @sprite.bitmap = Itefu::Rgss3::Window.default_skin
    @sprite.src_rect = Rect.new(64, 64, 32, 32)
    @sprite.visible = false
    @sprite.ox = @sprite.oy = 0
    @count = 0
    @anime_counter = 0
  end
  
  def on_finalize
    if @sprite
      @sprite.dispose
      @sprite = nil
    end
  end
  
  def on_update
    if @sprite
      @anime_counter += 0x7
      if @anime_counter >= 0x5f
        @anime_counter = -0x5f
      end
      @sprite.opacity = 0xff - @anime_counter.abs
      @sprite.update
    end
  end
  
  def set_cursor_off
    @sprite.visible = false
    @count = 0
  end
  
  def set_cursor_on(x, y, count = COUNT_TO_KEEP_SHOWING)
    su = @manager.scroll_unit
    mi = @manager.active_instance      # map_instance
    tm = mi.tilemap.tilemap   # tilemap
    dx = (su.scroll_x + tm.ox).to_i % mi.cell_size
    dy = (su.scroll_y + tm.oy).to_i % mi.cell_size
    @sprite.x = (x + dx) / mi.cell_size * mi.cell_size - dx
    @sprite.y = (y + dy) / mi.cell_size * mi.cell_size - dy
    @sprite.zoom_x = mi.cell_size / DEFAULT_CELL_SIZE
    @sprite.zoom_y = mi.cell_size / DEFAULT_CELL_SIZE
    @sprite.visible = true
    @count = count if count

    cx = mi.normalized_cell_x((x + tm.ox) / mi.cell_size)
    cy = mi.normalized_cell_y((y + tm.oy) / mi.cell_size)
    @sprite.color = mi.passable_tile?(cx, cy, Itefu::Rgss3::Definition::Direction::NOP) || mi.find_symbolic_event_mapobject(cx, cy, &:to_be_checked?) ? Itefu::Color.Blue : Itefu::Color.Red
  end
  
  def update_cursor(screen_x, screen_y)
    if @pointer_x == screen_x && @pointer_y == screen_y
      # マウスを動かさずにじっとしている
      if @count > 0
        @count -= 1
        if @count == 0
          set_cursor_off
        else
          set_cursor_on(screen_x, screen_y, nil)
        end
      end
    elsif @pointer_x && @pointer_y
      # マウスを動かした
      set_cursor_on(screen_x, screen_y)
    end
    @pointer_x = screen_x
    @pointer_y = screen_y
  end
  
end

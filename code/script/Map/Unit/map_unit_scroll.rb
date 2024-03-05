=begin  
=end
class Map::Unit::Scroll < Map::Unit::Base
  def default_priority; Map::Unit::Priority::SCROLL; end
  
  Direction = Itefu::Rgss3::Definition::Direction::Orthogonal
  
  attr_reader :scroll_x, :scroll_y
  attr_reader :center_x_min, :center_x_max
  attr_reader :center_y_min, :center_y_max
  
  # スクロール中処理中か
  def scrolling?; @scroll_speed.nil?.!; end
  
  def on_suspend
    {
      scroll_x: @scroll_x,
      scroll_y: @scroll_y,
      center_x_min: @center_x_min,
      center_x_max: @center_x_max,
      center_y_min: @center_y_min,
      center_y_max: @center_y_max,
      scroll_speed: @scroll_speed,
      scroll_dest_x: @scroll_dest_x,
      scroll_dest_y: @scroll_dest_y,
    }
  end
  
  def on_resume(context)
    @scroll_x = context[:scroll_x]
    @scroll_y = context[:scroll_y]
    @center_x_min = context[:center_x_min]
    @center_x_max = context[:center_x_max]
    @center_y_min = context[:center_y_min]
    @center_y_max = context[:center_y_max]
    @scroll_speed = context[:scroll_speed]
    @scroll_dest_x = context[:scroll_dest_x]
    @scroll_dest_y = context[:scroll_dest_y]
  end
  
  # スクロール処理を行う(イベント用)
  def start_event_scroll(direction, distance, speed)
    case direction
    when Direction::DOWN
      start_scroll(0, distance * @cell_size, speed)
    when Direction::LEFT
      start_scroll(-distance * @cell_size, 0, speed)
    when Direction::RIGHT
      start_scroll(distance * @cell_size, 0, speed)
    when Direction::UP
      start_scroll(0, -distance * @cell_size, speed)
    else
      raise Itefu::Exception::Unreachable
    end
  end
  
  # スクロール処理を行う
  def start_scroll(dx, dy, speed)
    if @scroll_dest_x
      @scroll_dest_x += dx
    else
      @scroll_dest_x = @scroll_x + dx
    end
    if @scroll_dest_y
      @scroll_dest_y += dy
    else
      @scroll_dest_y = @scroll_y + dy
    end
    @scroll_speed = Itefu::Rgss3::Definition::Event::Speed.to_cell(speed)
  end
  
  # スクロール位置をリセットする
  def reset_scroll
    @scroll_x = @scroll_y = 0
  end

  # スクロール位置を現在の場所までに制限する
  def limit_center(t, b, l, r)
    unit_player = @map_instance.player
    unit_tilemap = @map_instance.tilemap
    tilemap = unit_tilemap.tilemap

    @center_x_min = @center_x_max = @scroll_x + unit_player.real_x + tilemap.cell_width
    @center_y_min = @center_y_max = @scroll_y + unit_player.real_y + tilemap.cell_height / 2
    @center_y_min = nil unless t
    @center_y_max = nil unless b
    @center_x_min = nil unless l
    @center_x_max = nil unless r
  end

  def scroll(x, y)
    @scroll_x = x if x
    @scroll_y = y if y
  end

  def on_initialize(vp, cell_size, scroll_type)
    @map_instance = @manager
    @cell_size = cell_size
    @scroll_type = scroll_type
    @scroll_x = @scroll_y = 0
  end

  def on_update
    return unless state_started?
    update_event_scroll
    update_auto_scroll
  end
  
private

  # スクロール処理を行う
  def update_event_scroll
    return unless scrolling?
    
    dx = @scroll_dest_x - @scroll_x
    dy = @scroll_dest_y - @scroll_y
    if dx == 0 && dy == 0
      ax = ay = 0
    else
      dir = Math.atan2(dy, dx)
      ax = Math.cos(dir) * @cell_size * @scroll_speed
      ay = Math.sin(dir) * @cell_size * @scroll_speed
    end
    
    @scroll_x = (dx.abs - ax.abs < 0) ? @scroll_dest_x : @scroll_x + ax
    @scroll_y = (dy.abs - ay.abs < 0) ? @scroll_dest_y : @scroll_y + ay
    
    if (@scroll_x == @scroll_dest_x) && (@scroll_y == @scroll_dest_y)
      @scroll_speed = @scroll_dest_x = @scroll_dest_y = nil
      @scroll_x = @map_instance.normalized_real_x(@scroll_x.to_i)
      @scroll_y = @map_instance.normalized_real_x(@scroll_y.to_i)
    end
  end
  
  # プレイヤーに追従してスクロールする
  def update_auto_scroll
    unit_player = @map_instance.player
    unit_events = @map_instance.events
    unit_tilemap = @map_instance.tilemap
    
    tilemap = unit_tilemap.tilemap

    center_x = Itefu::Utility::Math.clamp_with_nil(@center_x_min, @center_x_max, @scroll_x + unit_player.real_x + tilemap.cell_width)
    center_y = Itefu::Utility::Math.clamp_with_nil(@center_y_min, @center_y_max, @scroll_y + unit_player.real_y + tilemap.cell_height / 2)
    unit_tilemap.centerize(center_x, center_y, @scroll_type)
    
    ox = tilemap.ox
    oy = tilemap.oy
    unit_player.update_scroll(ox, oy)
    unit_events.update_scroll(ox, oy)
    
    if pu = parallax_unit
      pu.update_scroll(ox, oy)
    end
  end
  
  
private

  def parallax_unit
    return unless Map::Unit.const_defined?(:Parallax)
    @map_instance.unit(Map::Unit::Parallax.unit_id)
  end

 end

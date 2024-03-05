=begin  
=end
class Map::Unit::Tilemap < Map::Unit::Base
  def default_priority; Map::Unit::Priority::TILEMAP; end
  MAP_SIZE_CAPACITY = 100 * 100
  DEFAULT_CELL_SIZE = Itefu::Tilemap::DEFAULT_CELL_SIZE

  attr_reader :tilemap

  def on_initialize(map_id, cell_size, map_data, flags, bitmaps, viewport)
    @map_id = map_id

    case
    when cell_size == DEFAULT_CELL_SIZE
      @tilemap = Itefu::Rgss3::Tilemap.new(viewport)
    when map_data.xsize * map_data.ysize < MAP_SIZE_CAPACITY
      @tilemap = Itefu::Rgss3::Tilemap::Predraw.new(viewport)
      @tilemap.cell_width = @tilemap.cell_height = cell_size
    else
      @tilemap = Itefu::Rgss3::Tilemap::Redraw.new(viewport)
      @tilemap.cell_width = @tilemap.cell_height = cell_size
    end
    
    bitmaps.each.with_index {|b, i| @tilemap.bitmaps[i] = b }
    @tilemap.map_data = map_data
    @tilemap.flags = flags
  end
  
  def on_finalize
    if @tilemap
      @tilemap.dispose
      @tilemap = nil
    end
  end
  
  def on_update
    return unless state_started?
    @tilemap.update if @tilemap
  end
  
  # 指定した座標が中央にくるようにタイルマップをスクロールする
  # @param [Fixnum] real_x マップ内絶対座標
  # @param [Fixnum] real_y マップ内絶対座標
  def centerize(real_x, real_y, scroll_type = Itefu::Rgss3::Definition::Map::ScrollType::FIX)

    if real_x
      cx = @tilemap.screen_width / 2

      if Itefu::Rgss3::Definition::Map::ScrollType.loop_horizontally?(scroll_type)
        @tilemap.ox = real_x - cx
      else
        tw = @tilemap.map_data.xsize * @tilemap.cell_width
        @tilemap.ox = Itefu::Utility::Math.clamp(0, tw - @tilemap.screen_width, real_x - cx)
      end
    end

    if real_y
      cy = @tilemap.screen_height / 2

      if Itefu::Rgss3::Definition::Map::ScrollType.loop_vertically?(scroll_type)
        @tilemap.oy = real_y - cy
      else
        th = @tilemap.map_data.ysize * @tilemap.cell_height
        @tilemap.oy = Itefu::Utility::Math.clamp(0, th - @tilemap.screen_height, real_y - cy)
      end
    end
  end
  
  # @return [Boolean] 指定した座標が画面内にあるか
  # @param [Fixnum] real_x マップ内絶対座標
  # @param [Fixnum] real_y マップ内絶対座標
  def in_the_sight?(real_x, real_y)
    cx = @tilemap.screen_width / 2
    cy = @tilemap.screen_height / 2
    (@tilemap.ox + cx - real_x).abs < (cx + @tilemap.cell_width*2) && (@tilemap.oy + cy - real_y).abs < (cy + @tilemap.cell_height*2)
  end

end

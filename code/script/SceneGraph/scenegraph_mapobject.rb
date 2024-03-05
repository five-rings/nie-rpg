=begin  
=end
class SceneGraph::MapObject < Itefu::SceneGraph::Sprite
  attr_accessor :direction
  attr_accessor :pattern
  attr_accessor :auto_anime
  attr_reader :graphic
  attr_reader :cw, :ch
  
  TILE_SIZE = Itefu::Rgss3::Definition::Tile::SIZE
  BUSH_DEPTH = 8
  
  # def clear_buffer; @sprite.bitmap = nil if @sprite; end
  
  def initialize(parent, viewport = nil)
    @to_create_buffer = false
    @cw = @ch = TILE_SIZE
    super(parent, @cw, @ch, nil, nil, nil)
    @sprite.viewport = viewport if viewport
  end

  def apply_graphic(bitmap, graphic, reset_direction = true)
    @bitmap = bitmap
    @graphic = graphic
    @pattern = graphic.pattern
    @direction = graphic.direction if reset_direction
    if Itefu::Rgss3::Definition::Tile.valid_id?(graphic.tile_id)
      @ch = @cw = TILE_SIZE
    else
      row, col = Itefu::Rgss3::Definition::Tile.image_grids(graphic.character_name)
      @cw = bitmap.width  / row
      @ch = bitmap.height / col
    end
    offset((size_w - @cw) / 2, (size_h - @ch))
    anchor(@cw / 2, @ch)
    @bush = false
    @need_to_update = true
  end
  
  def z=(z)
    sprite.z = z
  end
  
  def direction=(value)
    return if @direction == value
    @direction = value
    @need_to_update = true
  end

  def pattern=(value)
    v = value % Itefu::Rgss3::Definition::Tile::PATTERN_MAX
    return if @pattern == v
    @pattern = v
    @need_to_update = true
  end
  
  def bush=(value)
    return if @bush == value
    @bush = value
    @need_to_update = true
  end


private

  def impl_update
    if @auto_anime
      @auto_pattern ||= self.pattern * @auto_anime
      @auto_pattern += 1
      self.pattern = (@auto_pattern / auto_anime)
    end
    if @need_to_update
      @need_to_update = false
      update_graphic if @graphic
    end
    super
  end
  
  def impl_resize(w, h)
    super
    @sprite.src_rect.width = TILE_SIZE
    @sprite.src_rect.height = TILE_SIZE
    @sprite.zoom_x = w.to_f / TILE_SIZE
    @sprite.zoom_y = h.to_f / TILE_SIZE
    offset((w - @cw) / 2, (h - @ch))
    @children.each {|child| child.resize(w, h) }
  end
  
  def update_graphic
    if @bitmap
      sprite.bitmap = @bitmap
      @bitmap = nil
    end
    if Itefu::Rgss3::Definition::Tile.valid_id?(@graphic.tile_id)
      # 地形などのタイル
      @sprite.src_rect.x = Itefu::Rgss3::Definition::Tile.tile_x(@graphic.tile_id)
      @sprite.src_rect.y = Itefu::Rgss3::Definition::Tile.tile_y(@graphic.tile_id)
      @sprite.src_rect.width  = TILE_SIZE
      @sprite.src_rect.height = TILE_SIZE
    else
      # 人物などのキャラクター
      pattern = Itefu::Rgss3::Definition::Tile.pattern(@pattern)
      @sprite.src_rect.x = Itefu::Rgss3::Definition::Tile.image_x(@graphic.character_index, pattern, @cw)
      @sprite.src_rect.y = Itefu::Rgss3::Definition::Tile.image_y(@graphic.character_index, @direction, @ch)
      @sprite.src_rect.width  = @cw
      @sprite.src_rect.height = @ch
    end
    @sprite.bush_depth = @bush ? BUSH_DEPTH : 0
  end

end

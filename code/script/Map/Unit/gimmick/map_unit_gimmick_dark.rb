=begin
  プレイヤーの周辺を残してあたりを真っ暗にする
=end
class Map::Unit::Gimmick::Dark
  include Itefu::Resource::Loader
  FILL_COLOR = Itefu::Color.Black
  FILE_DARK = Filename::Graphics::Gimmick::PATH + "/dark"
  
  def suspend; @sprite && [@sprite.opacity]; end
 
  def initialize(unit, viewport, opacity = nil)
    super
    @parent_unit = unit
    @sprite = Itefu::Rgss3::Sprite.new(viewport)
    @sprite.z = 255
    @sprite.opacity = opacity if opacity
    rect = viewport.rect
    Itefu::Rgss3::Bitmap.new(rect.width, rect.height).auto_release {|bitmap|
      @sprite.bitmap = bitmap
    }
    @x = nil
    @y = nil
    @res_id = load_bitmap_resource(FILE_DARK)
  end

  def finalize
    if @sprite
      @sprite.dispose
      @sprite = nil
    end
    release_all_resources
  end
      
  def update
    return unless @sprite

    player = player_unit
    x = player.screen_x
    y = player.screen_y
    if @x != x || @y != y
      @x = x
      @y = y
      bitmap = resource_data(@res_id)
      cell_width = cell_height = player.cell_size

      scale = 10
      rect = Rect.new(x-cell_width/2*scale+cell_width/2, y-cell_height/2*scale, cell_width*scale, cell_height*scale)
      @sprite.bitmap.fill_rect(@sprite.bitmap.rect, FILL_COLOR)
      @sprite.bitmap.clear_rect(rect)
      @sprite.bitmap.stretch_blt(rect, bitmap, bitmap.rect)
    end
  end
  

private

  def player_unit
    @parent_unit.player
  end

end

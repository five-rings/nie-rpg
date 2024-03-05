=begin
  画面に白い靄を発生させる
=end
class Map::Unit::Gimmick::Fog
  include Itefu::Resource::Loader
  FILE_FOG = Filename::Graphics::Gimmick::PATH + "/fog"
  FOG_SPEED = 0.5
  
  def suspend; end
 
  def initialize(unit, viewport, speed = FOG_SPEED)
    super
    res_id = load_bitmap_resource(FILE_FOG)
    @fog_count = 0
    @sprite = Itefu::Rgss3::Plane.new(viewport)
    @sprite.z = 255
    @x = nil
    @y = nil
    @speed = speed
    @sprite.bitmap = resource_data(res_id)
    @sprite.zoom_x = 2
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

    @fog_count += @speed
    if @fog_count >= 1
      n = @fog_count.to_i
      @sprite.ox += n
      @fog_count -= n
    end
    @sprite.ox = 0 if @sprite.ox >= @sprite.bitmap.width * 2
  end
  
end

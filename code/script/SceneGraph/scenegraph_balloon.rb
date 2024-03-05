=begin
  フキダシ表示用 
  親ノードの上辺に下辺が接するように表示される
=end
class SceneGraph::Balloon < Itefu::SceneGraph::Sprite
  include Itefu::Resource::Loader

  ANIMATION_INTERVAL = 10
  TILE_SIZE = Itefu::Rgss3::Definition::Tile::SIZE
  
  def animating?; @balloon_id.nil?.!; end
  
  def initialize(parent, viewport = nil)
    # @hack 本来はsuperを呼んでからでないとリソースを読めないので無理矢理Resource::Loaderを初期化する
    initialize_resource_variables
    res_id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BALLOON)
    super(parent, TILE_SIZE, TILE_SIZE, resource_data(res_id), 0, 0)
    @sprite.viewport = viewport if viewport
    self.visibility = false
  end
  
  def finalize
    super
    release_all_resources
  end
  
  def z=(z)
    @sprite.z = z + 1
  end

  def start_animation(balloon_id, loop = nil)
    @balloon_id = balloon_id
    @anime_frame = 0
    @anime_counter = 0
    @loop = loop unless loop.nil?
  end
  
  def stop_animation
    if @loop
      @loop = false
    else
      @balloon_id = nil
    end
  end

  def stop_animation_forcibly
    @loop = false
    @balloon_id = nil
  end

  
private

  def impl_resize(w, h)
    super
    @sprite.zoom_x = w.to_f / TILE_SIZE
    @sprite.zoom_y = h.to_f / TILE_SIZE
    @children.each {|child| child.resize(w, h) }
  end
  
  def impl_update
    update_balloon
    super
  end
  
  def update_balloon
    if animating?
      @anime_counter += 1
      if @anime_counter >= ANIMATION_INTERVAL
        @anime_counter = 0
        @anime_frame += 1
        if @anime_frame >= Itefu::Rgss3::Definition::Balloon::ANIMATION_FRAME_SIZE
          if @loop
            @anime_frame = 0
          else
            stop_animation
          end
        end
      end
    end
    return unless self.visibility = animating?
    
    sx = Itefu::Rgss3::Definition::Balloon.image_x(@balloon_id, @anime_frame)
    sy = Itefu::Rgss3::Definition::Balloon.image_y(@balloon_id, @anime_frame)
    @sprite.src_rect.set(sx, sy, Itefu::Rgss3::Definition::Balloon::SIZE, Itefu::Rgss3::Definition::Balloon::SIZE)
    
    # @todo 現状だと大きいサイズのイベントグラフィックの場合に位置がずれる
    # mapobjectのchを取得してその分を引くようにするか, mapobjectの子にして親のを取得するようにするか
    transfer(0, -size_h)
  end
  
end

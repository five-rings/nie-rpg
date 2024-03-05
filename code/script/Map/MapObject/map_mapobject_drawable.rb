=begin
=end
module Map::MapObject::Drawable
  include Itefu::Resource::Loader
  include Itefu::Animation::Player
  ANIME_COUNTER_MAX = 10      # 歩行アニメなどのパターンを何フレームで切り替えるか
  NORMAL_Z = Itefu::Rgss3::Definition::Event::PriorityType.to_z(Itefu::Rgss3::Definition::Event::PriorityType::NORMAL) 
  BALLOON_Z = Itefu::Rgss3::Definition::Event::PriorityType.to_z(Itefu::Rgss3::Definition::Event::PriorityType::OVERLAY) 

  attr_accessor :direction    # [Itefu::Rgss3::Definition::Direction]
  attr_accessor :walk_anime   # [Boolean]
  attr_accessor :step_anime   # [Boolean]
  attr_accessor :bush         # [Boolean]
  attr_accessor :transparent  # [Boolean]
  attr_accessor :opacity          # [Fixnum]
  attr_accessor :blending_method  # [Itefu::Rgss3::Sprite::BlendingMethod]

  attr_reader :graphic
  attr_reader :anime_patterncounter
  attr_reader :scenegraph

  def tileset; raise Itefu::Exception::NotImplemented; end
  def disabled?; false; end
  def walk_anime?; walk_anime; end
  def step_anime?; step_anime; end

  def tile_id; (g = graphic) && g.tile_id; end
  def target_sprite; scenegraph.child(:map_object).sprite; end

  Direction = Itefu::Rgss3::Definition::Direction
  Tile = Itefu::Rgss3::Definition::Tile

  def initialize(*args)
    @direction = Direction::DOWN
    @walk_anime = true
    @opacity = 0xff 
    @blending_method = Itefu::Rgss3::Sprite::BlendingType::NORMAL
    
    create_scenegraph
    update_screen_xy(0, 0)
    update_screen_z(NORMAL_Z)
    reset_anime_pattern
    super
  end
  
  def finalize_drawable
    finalize_animations
    release_all_resources
    if @scenegraph
      @scenegraph.finalize
      @scenegraph = nil
    end
  end
  
  def update_drawable
    update_anime_pattern unless disabled?

    visible = disabled?.! && transparent.!
    @scenegraph.visibility = visible
    @scenegraph.children.each do |child|
      child.sprite.blend_type = @blending_method
      child.sprite.opacity = @opacity
    end

    @scenegraph.update
    update_animations
    if mapobj = @scenegraph.child(:map_object)
      mapobj.bush = @bush
    end
    @scenegraph.update_interaction
    @scenegraph.update_actualization
  end
  
  def draw_drawable
    @scenegraph.draw
  end
  
  def update_screen_xy(x, y)
    if screen_x != x || screen_y != y
      @scenegraph.transfer(x, y)
    end
  end
  
  def update_screen_z(z)
    @scenegraph.children.each do |child|
      child.z = z
    end
    if node = @scenegraph.child(:balloon)
      node.z = BALLOON_Z
    end
  end
  
  def screen_x
    @scenegraph.screen_x
  end
  
  def screen_y
    @scenegraph.screen_y
  end
  
  def assign_viewport(vp)
    @scenegraph.children.each do |child|
      child.sprite.viewport = vp
    end
  end

  # --------------------------------------------------
  # 歩行アニメ

  def reset_anime_pattern
    @anime_pattern_counter = 0
    if mapobj = @scenegraph.child(:map_object)
      mapobj.pattern = @graphic ? @graphic.pattern : 1
    end
  end
  
  def anime_counter_max; ANIME_COUNTER_MAX; end

  def update_anime_pattern
    if walk_anime? || step_anime?
      @anime_pattern_counter += 1
      if @anime_pattern_counter > anime_counter_max
        @anime_pattern_counter = 0
        @scenegraph.child(:map_object).pattern += 1
      end
    else
      reset_anime_pattern
    end
    if mapobj = @scenegraph.child(:map_object)
      mapobj.direction = direction if direction
    end
  end

  def apply_graphic(graphic, to_reset_direction = true)
    return unless graphic && (node = @scenegraph.child(:map_object))
    @graphic = graphic
    
    if Tile.valid_id?(graphic.tile_id)
      id_image = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::TILESETS_s % tileset.tileset_names[Tile.tileset_index(graphic.tile_id)])
    else
      id_image = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::CHARACTERS_s % graphic.character_name)
    end
    release_resource(@id_image) if @id_image
    @id_image = id_image
    node.apply_graphic(resource_data(id_image), graphic, to_reset_direction)
    @direction = graphic.direction if to_reset_direction
  end

  def apply_graphic_by_name(name, index, to_reset_direction = false)
    graphic = RPG::Event::Page::Graphic.new
    graphic.character_name = name
    graphic.character_index = index
    graphic.pattern = 1
    apply_graphic(graphic, to_reset_direction)
  end
  
  def apply_graphic_by_detail(name, index, direction, pattern)
    graphic = RPG::Event::Page::Graphic.new
    graphic.character_name = name
    graphic.character_index = index
    graphic.direction = direction
    graphic.pattern = pattern
    apply_graphic(graphic, true)
  end

  # --------------------------------------------------
  # その他

  def start_balloon(balloon_id, loop = nil)
    if node = @scenegraph.child(:balloon)
      node.start_animation(balloon_id, loop)
    end
  end
  
  def stop_balloon
    if node = @scenegraph.child(:balloon)
      node.stop_animation
    end
  end

  def stop_balloon_forcibly
    if node = @scenegraph.child(:balloon)
      node.stop_animation_forcibly
    end
  end
  
  def balloon_showing?
    (node = @scenegraph.child(:balloon)) && node.animating?
  end
  
=begin
  def show_unread_icon(enabled = true)
    if node = @screen_nodes[:unread]
      node.active = enabled
    end
  end
=end
  
  # はじき飛ばされ演出を再生する
  def start_being_smashed
    return unless (node = @scenegraph.child(:map_object))
    node(:map_object).ox = node(:map_object).oy = 0.5
    
    angle = rand(0) * Itefu::Utility::Math::Radian::FULL_CIRCLE
    offset_x = Math.cos(angle) * 6.0
    offset_y = Math.sin(angle) * 6.0

    Itefu::Animation::Base.new.updater {|a|
      c = a.play_count
      if c < 20
        node.offset_x = (offset_x * c).to_i
        node.offset_y = (offset_y * c).to_i
        node.sprite.angle = (c * 45) % Itefu::Utility::Math::Degree::FULL_CIRCLE
        node.sprite.visible = true
      else
        a.finsh
      end
    }.play(self, :smashing)
  end
  
  # ジャンプ演出を再生する
  def start_jumping(count)
    return unless (node = @scenegraph.child(:map_object))
    return if jumping?

    offset_base = (count / 2) ** 2
    Itefu::Animation::Base.new.updater {|a|
      c = a.play_count
      if c < count
        node.offset(nil, ((c - count/2)**2 - offset_base).to_i)
      else
        a.finish
      end
    }.finisher {
        node.offset(nil, 0)
    }.play(self, :jumping)
  end
  
  def jumping?
    playing_animation?(:jumping)
  end
  
  def resize(w, h)
    @scenegraph.children.each do |child|
      child.resize(w, h)
    end
  end

  def recreate_sprite
    if mapobj = @scenegraph.child(:map_object)
      mapobj.recreate_sprite
    end
  end
  
private

  def create_scenegraph
    @scenegraph = Itefu::SceneGraph::Root.new
    @scenegraph.add_child_id(:map_object, SceneGraph::MapObject)
    @scenegraph.add_child_id(:balloon, SceneGraph::Balloon)
  end

end

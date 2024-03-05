=begin
=end
class Map::Unit::MapObject < Map::Unit::Base
  include Itefu::Utility::Callback
  include Map::MapObject::Movable
  include Map::MapObject::Drawable

  attr_accessor :map_instance
 
  def player; map_instance.player; end
  def events; map_instance.events; end
  def cell_size; map_instance.cell_size; end
  def tileset; map_instance.tileset; end
  def walk_anime?; super && moving?; end
  def map_structure; map_instance; end
  def passable_cell?(cell_x, cell_y, dir); map_structure.passable_cell?(cell_x, cell_y, dir); end
  def in_map_cell?(cell_x, cell_y); map_structure.in_map_cell?(cell_x, cell_y); end
 
  def normalized_real_x(x); map_instance.normalized_real_x(x); end
  def normalized_real_y(y); map_instance.normalized_real_y(y); end
  def normalized_cell_x(x); map_instance.normalized_cell_x(x); end
  def normalized_cell_y(y); map_instance.normalized_cell_y(y); end
  def distance_cell_x(sx, gx); map_instance.distance_cell_x(sx, gx); end
  def distance_cell_y(sy, gy); map_instance.distance_cell_y(sy, gy); end
  
  module Gait
    WALK = 0
    SNEAK = -1
    DASH = 1
  end
  attr_reader :gait_speed
  def move_speed; Itefu::Utility::Math.max(1, super + (gait_speed || 0)); end

  def anime_counter_max
    super * 4 / move_speed
  end

  def map_instance=(instance)
    @map_instance = instance
    @routes.each {|route| route.map_instance = instance } if @routes
    size = instance.cell_size
    resize(size, size)
  end

  include Map::MapObject::BehaviorTree
  def bt_manager; map_instance; end

  RESUME_TARGETS = [
      :@real_x,
      :@real_y,
      :@dest_x,
      :@dest_y,
      :@cell_x,
      :@cell_y,
      :@direction,
      :@jumping,
      :@move_speed,
      :@direction_fixed,
      :@passable,
      :@move_frequency,
      :@routes,
      :@walk_anime,
      :@step_anime,
      :@bush,
      :@transparent,
      :@opacity,
      :@blending_method,
      :@graphic,
      :@rotate_angle,
      :@offset_x,
      :@offset_y,
      :@mirror,
      :@zoom_scale,
      :@tone,
    ]
  def resume_targets; RESUME_TARGETS; end

  def on_suspend
    data = {}
    resume_targets.each do |key|
      data[key] = instance_variable_get(key) if instance_variable_defined?(key)
    end

    # BehaviorTree
    if @bt_root && @bt_root.alive?
      if bt_context = behavior_tree_context
        if data[:@bt_context] = bt_context.clone
          data[:@bt_context][:map_object] = nil
        end
      end
      data[:@bt_status] = @bt_root.save_status
    end

    data
  end
  
  def on_resume(context)
    if @graphic && context.has_key?(:@graphic).!
      dir = @direction
    end
    context.each do |key, value|
      instance_variable_set(key, value)
    end

    # 見た目を復元
    if context.has_key?(:@graphic)
      apply_graphic(@graphic, false)
    else
      @direction = dir if dir
    end

    if context.has_key?(:@rotate_angle)
      rotate(@rotate_angle)
    end

    if context.has_key?(:@offset_x) || context.has_key?(:@offset_y)
      shift(@offset_x, @offset_y)
    end

    if context.has_key?(:@mirror)
      mirror(@mirror)
    end

    if context.has_key?(:@zoom_scale)
      scale(@zoom_scale)
    end

    if context.has_key?(:@tone)
      tone(@tone)
    end

    # BehaviorTree
    if context = @bt_context
      @bt_context = nil
      context[:map_object] = self
      setup_behavior_tree(context[:sc_type], context)
    end
    if @bt_root && @bt_status
      @bt_root.load_status(@bt_status)
      @bt_status = nil
    end

    # Routeを復元
    @routes.each {|route| route.map_instance = map_instance } if @routes
  end
  
  def on_unit_state_changed(old)
    case @unit_state
    when Map::Unit::State::STARTED
      # 初期位置などcell座標だけ指定されている場合は、cell座標を元に復帰する
      if (@real_x.nil? || @real_y.nil?) && (@cell_x && @cell_y)
        transfer_to_cell(@cell_x, @cell_y, true)
      end
    end
  end

  def on_finalize
    clear_behavior_tree_node
    finalize_drawable
  end

  def on_update
    update_movable
    update_drawable
  end
 
  def on_draw
    draw_movable
    draw_drawable
  end

  def jump(*args)
    super
    start_jumping(@jumping)
  end
  
  def update_route_moving
    super unless jumping?
  end

  def add_route(route, object = nil)
    object ||= player
    route_instance = Map::MapObject::Route.new(map_instance, route, self, object)
    add_route_instance(route_instance)
  end
  
  def update_cell_position
    super
    cx = cell_x
    cy = cell_y
    self.bush = false if graphic && map_instance.bush_tile?(cx, cy).!
    turn(Direction::UP) if map_instance.ladder_tile?(cx, cy)
  end
  
  def on_moved(warped)
    self.bush = map_instance.bush_tile?(cell_x, cell_y) if graphic
    execute_callback(:moved, warped)
  end
  
  def on_unmoved(dir)
    execute_callback(:unmoved, dir)
  end
  
  def update_scroll(ox, oy)
    x = map_structure.screen_x(real_x, ox)
    y = map_structure.screen_y(real_y, oy)
    update_screen_xy(x, y)
  end
  
  def change_graphic(chara_name, chara_index)
    if @graphic
      graphic = @graphic.clone
      graphic.tile_id = 0
      graphic.character_name = chara_name
      graphic.character_index = chara_index
      apply_graphic(graphic, false)
    else
      apply_graphic_by_name(chara_name, chara_index, false)
    end
  end

  # イベントで回転させる用
  def rotate(angle)
    node = @scenegraph.child(:map_object)
    node.anchor(0.5, 0.5)
    node.sprite.angle = @rotate_angle = angle
  end

  # イベントでずらして表示する用
  def shift(x = nil, y = nil)
    if node = @scenegraph.child(:map_object)
      node.offset_x = @offset_x = x if x
      node.offset_y = @offset_y = y if y
    end
    if node = @scenegraph.child(:balloon)
      node.offset_x = @offset_x = x if x
      node.offset_y = @offset_y = y if y
    end
  end

  def mirror(value)
    node = @scenegraph.child(:map_object)
    node.sprite.mirror = @mirror = value
  end

  def scale(value)
    node = @scenegraph.child(:map_object)
    node.sprite.zoom_x = node.sprite.zoom_y = @zoom_scale = value
  end

  def tone(*args)
    node = @scenegraph.child(:map_object)
    node.sprite.tone = @tone = args.size == 1 ? args[0] : Tone.new(*args)
  end
  
  # 移動できずに立ち往生する反応をする
  def standstill
    start_balloon(5, false)
  end
  
  # ゆっくり移動する
  def sneak(sneaking)
    if sneaking
      @gait_speed = Gait::SNEAK
    else
      @gait_speed = Gait::WALK
    end
  end

  # はやく移動する
  def dash(dashing)
    if gait_speed != Gait::SNEAK
      if dashing
        @gait_speed = Gait::DASH
      else
        @gait_speed = Gait::WALK
      end
    end
  end

  def dashing?; @gait_speed == Gait::DASH; end
  def sneaking?; @gait_speed == Gait::SNEAK; end

end


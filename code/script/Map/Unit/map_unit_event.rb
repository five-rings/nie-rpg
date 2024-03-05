=begin  
=end
class Map::Unit::Event < Map::Unit::MapObject
  def default_priority; @event_id; end
  def unit_id; @event_id; end
  def self.unit_id; raise Itefu::Exception::NotSupported; end

  attr_reader :event_id
  attr_reader :event
  attr_reader :stop         # [Boolean] イベント中などで停止しているか
  attr_reader :route
  # attr_reader :seed
  attr_reader :current_page_index

  def always_active?; false; end
  
  def map_id; attached? && map_instance.map_id; end
  def disabled?; @disabled; end
  def disable
    if sound = sound_unit
      sound.detach_source(self)
    end
    @disabled = true
  end
  
  def map_instance
    # detach されたときnilになりえる
    attached? && @manager.map_instance
  end
  
  def map_instance=(instance)
    size = instance.cell_size
    @routes.each {|route| route.map_instance = instance } if @routes
    @route.map_instance = instance if @route
    resize(size, size)
  end
  
  def sound_unit; @manager && map_instance.manager.sound_unit; end
  def enabled_to_update_behavior_tree?; super && disabled?.! && @stop.!; end
  def auto_walkable?; @auto_walk_count >= Itefu::Rgss3::Definition::Event::MoveFrequency.to_frame(@move_frequency); end

  def event_tile?
    enabled? && impassable? && Itefu::Rgss3::Definition::Tile.valid_id?(tile_id)
  end

  EventIconData = Struct.new(:icon_index, :range)

  RESUME_TARGETS = RESUME_TARGETS + [
      :@event_id,
      :@current_page_index,
      :@route,
      :@stop,
      :@dir_original,
      :@disabled,
      # :@symbolic_enemy,
      # :@seed
  ]
  def resume_targets; RESUME_TARGETS; end

  def on_resume(context)
    super
    @route.map_instance = map_instance if @route
  end

  def initialize(manager, event, *args)
    @event = event
    @event_id = event.id
    super
  end


  def on_initialize(event, viewport)
    self.map_instance = @manager
    @event_id = event.id
    @auto_walk_count = 0
    assign_viewport(viewport)
    transfer_to_cell(event.x, event.y, true)
    fetch_event_page
  end
  
  def on_finalize
    if sound = sound_unit
      sound.detach_source(self)
    end
    super
  end

  def on_update
    super

    unless disabled? || moving? || jumping? || @stop || detached?
      # 自動移動
      update_auto_walk
    end
    # 自動移動でdetachされる可能性がある
    return if detached?

    # イベント起動時に関係ないイベントアイコンが出っぱなしになるのを消す
    if @showing_event_icon && interpreter.running?
      close_event_icon
    end

    if sound = sound_unit
      sound.move_source(self)
    end
  end

  def on_attached
    if sound = sound_unit
      sound.attach_source(self)
    end
  end

  def on_detached
    @scenegraph.visibility = false
    @scenegraph.update_actualization
    if sound = sound_unit
      sound.detach_source(self)
    end
  end

  
  def on_unmoved(dir)
    super
    # イベントからの接触
    nx, ny = map_structure.next_cell(cell_x, cell_y, dir)
    if map_structure.walkable_tile?(cell_x, cell_y, dir) && map_structure.player_here?(nx, ny)
      trigger_event(Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_EVENT)
    end
  end

private

  def update_cell_position
    # イベントが更新対象外に移動した際に管理対象から外す
    old_x = @cell_x
    old_y = @cell_y
    super
    if old_x != @cell_x || old_y != @cell_y
      if state_opened?
        # 初期化中に移動してしまうと不都合があるのでちゃんとマップが開いてからにする
        # 具体的には resuming_context の処理が終わらないうちに元のcell_x,yで処理をしてしまうなど
        events.move_registered_event(event_id, self, @cell_x, @cell_y, old_x, old_y)
      end
    end
  end

  
public
  # --------------------------------------------------
  # イベント関連
  
  def current_page
    enabled? && @current_page_index && @event.pages[@current_page_index]
  end

  def interpreter; inst = map_instance; inst && inst.event_interpreter; end

  def trigger_event(how, dir = nil)
    # イベントが拘束されるようなイベントの起動の仕方をする場合に呼ぶ
    return unless page = current_page
    return unless page.trigger == how && enabled? && @smashed.!

    dir_original = direction
    if itpr = interpreter.start_main_event(map_id, event_id, current_page_index, page.list)
      if direction_fixed?.! && Itefu::Rgss3::Definition::Direction.valid?(dir)
        turn(dir)
      end
      @stop = true
      close_event_icon(true)
      @dir_original = dir_original
    end
    itpr
  end

  # 調べる／話しかけることで起動するイベントか
  def to_be_checked?
    return unless page = current_page
    return false unless page.trigger == Itefu::Rgss3::Definition::Event::Trigger::DECIDE
    return false if page.list.size <= 1
    true
  end
  
  def show_event_icon(distance)
    if @scenegraph.child(:balloon)
      target = self
    else
      target = player
    end

    if target.balloon_showing?
      return false unless @showing_event_icon
    end

    return false unless @event_icon_data
    return false unless id = @event_icon_data.icon_index

    if distance > @event_icon_data.range
      close_event_icon
      return false
    else
      return false if id == @showing_event_icon
    end

    @showing_event_icon = id
    target.start_balloon(id, true)
    true
  end

  def close_event_icon(force = false)
    if @scenegraph.child(:balloon)
      target = self
    else
      target = player
      force = true
    end

    if @showing_event_icon # || balloon_showing?
      @showing_event_icon = nil
      begin
        target.stop_balloon
      end while force && (target.balloon_showing?)
      true
    end
  end
  
  def turn_back
    turn(@dir_original) if Itefu::Rgss3::Definition::Direction.valid?(@dir_original)
  end
 
  def finish_event_command(interpreter, status)
    @stop = false
    # アイコン再表示=playerから呼ぶので不要
      # show_event_icon(@showing_event_icon) if @showing_event_icon
    # アイコンが一度だけ表示するタイプかもしれないので再チェックする
    if @event_icon_data
      @event_icon_data.icon_index = nil
      update_event_icon_data(current_page)
    end
    # end
    turn_back
  end

  def fetch_event_page
    if disabled?
      @current_page_index = nil
      @event_icon_data.icon_index = nil if @event_icon_data
      return
    end

    page_index = find_page_index_by_condition
    return if @current_page_index == page_index
    @event_icon_data.icon_index = nil if @event_icon_data
    @current_page_index = page_index
    return unless page_index

    page = @event.pages[page_index]
    @direction_fixed = page.direction_fix
    @passable        = page.through
    @walk_anime      = page.walk_anime
    @step_anime      = page.step_anime
    @move_speed      = page.move_speed
    @move_frequency  = page.move_frequency
    case page.move_type
    when Itefu::Rgss3::Definition::Event::MoveType::CUSTOM
      @route = Map::MapObject::Route.new(map_instance, page.move_route, self, player)
    end
    @routes.clear if @routes
    update_screen_z(Itefu::Rgss3::Definition::Event::PriorityType.to_z(page.priority_type))
    apply_graphic(page.graphic)

    update_event_icon_data(page)
    if sound = sound_unit
      sound.attach_source(self)
    end
  end

  def find_page_index_by_condition
    @event.pages.rindex {|page|
      c = page.condition
      if c.switch1_valid
        next false unless Map::SaveData.switch(c.switch1_id)
      end
      if c.switch2_valid
        next false unless Map::SaveData.switch(c.switch2_id)
      end
      if c.variable_valid
        next false if Map::SaveData.variable(c.variable_id) < c.variable_value
      end
      if c.self_switch_valid
        next false unless Map::SaveData.self_switch(map_id, event_id, c.self_switch_ch)
      end
      if c.item_valid
        next false unless Map::SaveData::GameData.inventory.has_item_by_id?(c.item_id)
      end
      if c.actor_valid
        next false unless Map::SaveData::GameData.party.has_member?(c.actor_id)
      end
      true
    }
  end

  def update_event_icon_data(page)
    return unless page
    return if Itefu::Rgss3::Definition::Event::Trigger.auto?(page.trigger)
    page.list.each {|command|
      # 冒頭にある注釈だけを確認する
      break unless (command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT ||
                    command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT_SEQUEL)
      if /^\*([^=,!]+)!?(?:=([0-9]+))?(?:\s*,\s*([0-9]+|n?[0-9]*))?$/ === command.parameters[0]
        id = case $1
             when "talk" # 会話できる
               7
             when "find" # 何かある
               0
             when "shop" # お店
               10
             when "curio" # 骨董商
               8
             when "warp" # ファストトラベル
               11
             when "skill" # スキル伝授
               12
             when "magic" # 秘術伝授
               13
             when "quest" # クエスト
               14
             when "icon" # 任意のアイコン
               Integer($2) rescue nil
             end
        if id && Map::SaveData::GameData.collection.event_checked?(map_id, event_id, current_page_index).!
          @event_icon_data ||= EventIconData.new
          @event_icon_data.icon_index = id
          if $3 && $3.start_with?("n")
            # nを数字に置き換えるか、nの後の数字を範囲とみなすか
            @event_icon_data.range = 3
            # @event_icon_data.range = Integer($3.delete("n")) rescue 1
          else
            @event_icon_data.range = $3 && Integer($3) || 1 rescue 1
          end
          break
        end
      end
    }
  end


  # --------------------------------------------------
  # 自動移動関連
  
  def update_auto_walk
    return unless routes.nil? || routes.empty?
    return unless page = current_page

    @auto_walk_count += 1
    return unless auto_walkable?

    case page.move_type
    when Itefu::Rgss3::Definition::Event::MoveType::RANDOM
      auto_walk_random
    when Itefu::Rgss3::Definition::Event::MoveType::APPROACH
      auto_walk_toward_player
    when Itefu::Rgss3::Definition::Event::MoveType::CUSTOM
      auto_walk_custom
    end
  end

  def auto_walk_random
    # @note オリジナルの実装に準拠
    case rand(6)
    when 0..1;  move_random
    when 2..4;  move_forward
    end
  end

  def auto_walk_toward_player
    distance_x = distance_x_from(player)
    distance_y = distance_y_from(player)
    # @note オリジナルの実装に準拠
    if distance_x.abs + distance_y.abs < 20
      case rand(6)
      when 0..3;  move_toward_mapobject(player)
      when 4;     move_random
      when 5;     move_forward
      end
    else
      move_random
    end
  end

  def auto_walk_custom
    @route.update if @route
  end
  
  def turn(dir)
    @auto_walk_count = 0
    @dir_original = nil
    super
  end

private

  def create_scenegraph
    case
    when @event.name.start_with?("#")
      @scenegraph = Itefu::SceneGraph::Root.new
    when @event.name.start_with?("&")
      @scenegraph = Itefu::SceneGraph::Root.new
      @scenegraph.add_child_id(:balloon, SceneGraph::Balloon)
    when @event.name.start_with?("+")
      @scenegraph = Itefu::SceneGraph::Root.new
      @scenegraph.add_child_id(:map_object, SceneGraph::MapObject)
    else
      super
    end
  end

end

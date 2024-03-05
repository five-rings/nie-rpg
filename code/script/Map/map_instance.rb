=begin
=end
class Map::Instance
  include Itefu::Resource::Loader
  include Itefu::Utility::State::Context
  include Itefu::Unit::Manager
  include Itefu::BehaviorTree::Manager
  include Map::Structure
  include Map::Path
  # include Map::WayPoint::Manager
  
  attr_reader :map_id
  attr_reader :cell_size
  attr_reader :width, :height
  attr_reader :manager
  attr_reader :sound_environment
  attr_reader :message, :message_map_name
  attr_reader :map_name, :map_default_name
  attr_reader :fairy_map_id
  attr_reader :no_notice
  
  def ready?; @ready; end
  def active?; @active; end
  def activate; self.active = true; end
  def deactivate; self.active = false; end
  def controlable?; state == State::Main; end
  def map_viewport; @viewports[:map]; end
  def map_data; @map; end
  def tileset; @tileset; end
  def tilemap; unit(Map::Unit::Tilemap.unit_id); end
  def player; @manager.unit(Map::Unit::Player.unit_id); end
  def events; unit(Map::Unit::Events.unit_id); end
  def event(event_id); events.unit(event_id); end
  def event_interpreter; @manager.unit(Map::Unit::Interpreter.unit_id); end
  def mapobject(unit_id)
    @manager.unit(unit_id) ||
    event(unit_id)
  end
  def map_instance; self; end

  # @return [Fixnum] resuming_contextからtileset_idを取り出す
  def self.tileset_id_from(context)
    if mycontext = context && context[:map_instance]
      mycontext[:tileset_id]
    end
  end
 
  def suspend(context)
    mycontext = context[:map_instance] = {}
    mycontext[:tileset_id] = @tileset_id if @tileset_id
    send_signal(:suspend, context)
  end
 
  def resume(context)
    if mycontext = context[:map_instance]
      # change_tileset(mycontext[:tileset_id]) if mycontext[:tileset_id]
    end
    send_signal(:resume, context)
  end

  def initialize(manager, map_id, x, y, width, height, default_cell_size = nil, tileset_id = nil)
    super
    @manager = manager
    @map_id = map_id
    @width = width
    @height = height
    @default_cell_size = default_cell_size || Itefu::Rgss3::Tilemap::DEFAULT_CELL_SIZE
    @tileset_id = tileset_id if tileset_id
    @active = false
    @viewports = {
      map: Itefu::Rgss3::Viewport.new(x, y, width, height).tap {|vp| vp.visible = false; vp.z = Map::Viewport::MAP },
      weather: Itefu::Rgss3::Viewport.new(x, y, width, height).tap {|vp| vp.visible = false; vp.z = Map::Viewport::WEATHER },
    }
    @sound_environment = Itefu::Sound::Environment.new.tap {|env|
      env.bgs_fade_speed = 2
    }
    @resource_ids = {}
    change_state(State::Initialize, map_id)
  end
  
  # インスタンス生成後に一度だけ呼ぶ
  def setup
    ITEFU_DEBUG_ASSERT(state == State::Initialize)
    change_state(State::Setup, map_id)
  end

  def finalize
    finalize_bt
    clear_state
    clear_all_units
    @viewports.each_value(&:dispose)
    @viewports.clear
    @resource_ids.clear
    if @message_map_name
      Application.language.release_message(:map_name)
      @message_map_name = nil
    end
    if @message
      if @message.chain
        Application.language.release_message(Filename::Language::MAP_TEXT_COMMON)
        Application.language.release_message(Filename::Language::MAP_TEXT_n % map_id)
      else
        Application.language.release_message(Filename::Language::MAP_TEXT_COMMON)
      end
      @message = nil
    end
    release_all_resources
  end
  
  def update
    update_state
    @viewports.each_value(&:update)
  end
  
  def draw
    draw_state
  end

  # アクティブかどうかを切り替える
  def active=(value)
    if @active != value
      @active = value
      @viewports.each_value {|vp| vp.visible = value unless vp.disposed? }
      if value
        activated
      else
        deactivated
      end
    end
  end

  # 処理を開始する
  def enter_to_main
    change_state(State::Main)
    send_signal(:change_state, Map::Unit::State::STARTED)
  end

  # タイルマップを切り替える
  def change_tileset(tileset_id)
    if (fade = @manager.fade) && fade.faded_out?.!
      fade.transit(10)
      to_be_resolved = true
    end

    @tileset = stored_data(:tilesets)[tileset_id]
    store_bitmap(:tileset_bitmaps,
      Itefu::Rgss3::Filename::Graphics::TILESETS_s,
      @tileset.tileset_names
    )
    
    tilemap = unit(Map::Unit::Tilemap.unit_id).tilemap
    stored_data(:tileset_bitmaps).each.with_index do |bitmap, i|
      tilemap.bitmaps[i] = bitmap
    end    
    tilemap.flags = @tileset.flags

    @tileset_id = tileset_id
    fade.resolve if to_be_resolved
  end
  
  # 遠景を切り替える
  def change_parallax(name, loop_x, loop_y, sx, sy)
    parallax = unit(Map::Unit::Parallax.unit_id)
    if name.nil? || name.empty?
      parallax.hide
    else
      parallax.show(name, loop_x, loop_y, sx, sy)
    end
  end

  def pick_troop_index_from_encounter_list(cell_x, cell_y)
    # check region id of here
    rid = self.region_id(cell_x, cell_y)

    # pick from encounter list
    Itefu::Utility::Array.weighted_randomly_select(self.map_data.encounter_list) {|ed|
      if ed.region_set.empty? || ed.region_set.include?(rid)
        ed.weight
      else
        0
      end
    }
  end


private

  # アクティブになった
  def activated
    @manager.attach_units(units)
    @manager.instance_activated(self)
    @manager.sound_unit.switch_environment(sound_environment)
  end

  # 非アクティブになった
  def deactivated
    @manager.detach_units(units)
  end


public

  # --------------------------------------------------
  # Initialize
  
  def on_state_initialize_attach(map_id)
    store_rvdata2(:tilesets, Itefu::Rgss3::Filename::Data::TILESETS)
  end
  
  # --------------------------------------------------
  # Setup
  
  def on_state_setup_attach(map_id)
    @map_id = map_id
    store_rvdata2(:map, Itefu::Rgss3::Filename::Data::MAP_n % map_id)
    # store_rvdata2(:waypoint, Filename::WayPoint::DATA_n % map_id)

    @map = map = stored_data(:map)
    @tileset = stored_data(:tilesets)[@tileset_id || map.tileset_id]

    setup_scroll_type(map_data.scroll_type)
    load_chara_resources(map)
    load_tileset_resources(tileset)
    load_message(map_id)

    @map_default_name = @map.display_name
    if @message_map_name
      key = "Map%03d" % map_id
      mapname = @message_map_name.text(key.intern)
      @map.display_name = mapname if mapname
    end

    setup_cell_size(map)
    setup_units(map, tileset)
    load_submaps(map)
    @map_name = map.display_name if Itefu::Utility::String.note_command(:show_map_name, map.note)
    @fairy_map_id = Itefu::Utility::String.note_command_i(:fairy_map_id=, map.note)
    if color_param = Itefu::Utility::String.note_command(:battle_cursor=, map.note)
      Map::SaveData::GameData.system.battle_cursor = Color.new(*color_param.split(",").map {|v| v.to_i })
    else
      Map::SaveData::GameData.system.battle_cursor = nil
    end
    @no_notice = Itefu::Utility::String.note_command(:no_notice, map.note)
    change_state(State::Open)
  end

  # キャラ画像を全て読み込む
  def load_chara_resources(map)
    store_bitmap(:charas,
      Itefu::Rgss3::Filename::Graphics::CHARACTERS_s,
      map.events.each_value.each_with_object([]) {|event, object|
        event.pages.each do |page|
          name = page.graphic.character_name
          object << name unless name.empty?
        end
      }
    )
  end
  
  # タイルセットで使用している画像を全て読み込む
  def load_tileset_resources(tileset)
    store_bitmap(:tileset_bitmaps,
      Itefu::Rgss3::Filename::Graphics::TILESETS_s,
      tileset.tileset_names
    )
  end
  
  # テキストデータを読み込む
  def load_message(map_id)
    if @message = Application.language.load_message(Filename::Language::MAP_TEXT_n % map_id) rescue nil
      @message.apply_chain Application.language.load_message(Filename::Language::MAP_TEXT_COMMON) rescue nil
    else
      @message = Application.language.load_message(Filename::Language::MAP_TEXT_COMMON) rescue nil
    end
    @message_map_name = Application.language.load_message(:map_name) rescue nil
  end
  
  # マップのセルサイズを設定する
  def setup_cell_size(map)
    cell_size = Itefu::Utility::String.note_command_i(:cell_size=, map.note)
    @cell_size = cell_size || @default_cell_size
  end

  # マップインスタンスごとのマップユニットを生成する
  def setup_units(map, tileset)
    vp_map = @viewports[:map]

    # gimmick
    unit_gimmick = add_unit(Map::Unit::Gimmick, vp_map).tap {|unit|
      unit.add_viewport(:weather, @viewports[:weather])
      if command = Itefu::Utility::String.note_command(:gimmick=, map.note)
        gimmick, *params = command.split(/,/)
        if gimmick
          params.map! {|p| Itefu::Utility::String.to_number(p) }
          unit.change_additional_gimmick(gimmick, *params)
        end
      end
    }
    # マップの初期トーン値が設定されていれば反映する
    if tone_param = Itefu::Utility::String.note_command(:tone=, map.note)
      tone = Tone.new(*tone_param.split(",").map {|v| v.to_i })
      unit_gimmick.change_tone(tone, 0)
    end

    # scroll
    add_unit(Map::Unit::Scroll, vp_map, @cell_size, map.scroll_type)

    # tilemap
    add_unit(Map::Unit::Tilemap,
      @map_id,
      @cell_size,
      map.data, tileset.flags, stored_data(:tileset_bitmaps),
      vp_map
    )
    
    # parallax
    add_unit(Map::Unit::Parallax, vp_map,
      map_data.parallax_name,
      map_data.parallax_loop_x,
      map_data.parallax_loop_y,
      map_data.parallax_sx,
      map_data.parallax_sy
    )

    # events
    add_unit(Map::Unit::Events).tap {|unit|
      if Itefu::Utility::String.note_command(:disable_space_division, map.note)
        # イベント生成時に環境音の登録を行うのでEnvironmentをこのマップのものに一旦設定しておく
        sound_unit = @manager.sound_unit
        env = sound_unit.switch_environment(sound_environment)
        unit.lazy_sort {
          map.events.each_value do |event|
            unit.register_event(event.id, event.x, event.y, event)
          end
        }
        # 一旦設定したものを戻す
        sound_unit.switch_environment(env)
      else
        unit.use_space_division
        map.events.each_value do |event|
          unit.register_event(event.id, event.x, event.y, event)
        end
      end
    }
  end

  # サブマップを読み込む
  def load_submaps(map)
    map.note.each_line do |line|
      if sub_map_id = Itefu::Utility::String.note_command_i(:sub_map=, line)
        @manager.add_instance(sub_map_id, @default_cell_size)
      end
    end
  end
  
  private :load_chara_resources, :load_tileset_resources, :setup_cell_size, :setup_units, :load_submaps

  # --------------------------------------------------
  # Open
  
  def on_state_open_attach
    state_work[:counter] = 0
  end
  
  def on_state_open_update
    if (state_work[:counter] += 1) > 1
      change_state(State::WaitToStart)
    end
  end

  def on_state_open_detach
    @ready = true
  end

  # --------------------------------------------------
  # Main

  def on_state_main_attach
  end

  def on_state_main_update
    return unless active?
    if @manager.exit_code
      change_state(State::Quit)
    else
      update_bt_trees
    end
  end
  
  def on_state_main_draw
    return unless active?
  end
  
  def on_state_main_detach
    @ready = false
  end


  # --------------------------------------------------
  # Quit
  def on_state_quit_attach
  end

  
private

  def store_resource_id(key, id)
    if @resource_ids.has_key?(key)
      old = @resource_ids[key]
      case old
      when Array
        old.each {|old_id| release_resource(old_id) }
      else
        release_resource(old)
      end
    end
    @resource_ids[key] = id
  end
  
  def store_rvdata2(key, filename, params = nil)
    if params
      store_resource_id(key, params.map {|param| load_rvdata2_resource(filename % param) })
    else
      store_resource_id(key, load_rvdata2_resource(filename))
    end
  rescue Errno::ENOENT
  end
  
  def store_bitmap(key, filename, params = nil)
    if params
      store_resource_id(key, params.map {|param|
        load_bitmap_resource(filename % param) unless param.empty?
      })
    else
      store_resource_id(key, load_bitmap_resource(filename))
    end
  end
  
  def stored_data(key, index = nil)
    return unless @resource_ids.has_key?(key)
    id = @resource_ids[key]
    case id
    when Array
      if index
        resource_data(id[index])
      else
        id.map {|i| resource_data(i) }
      end
    else
      resource_data(id)
    end
  end

end

=begin
=end
class Map::Manager
  include Itefu::Utility::State::Context
  include Itefu::Unit::Manager
  include Itefu::Animation::Player
  
  attr_reader :active_map_id, :map_id_to_transfer
  attr_reader :x, :y, :width, :height
  attr_reader :exit_code, :exit_param
  attr_reader :viewports
  attr_reader :fade
  attr_reader :sound
  attr_reader :database
  attr_reader :lang_message
  attr_reader :lang_common_events
  attr_reader :result     # [Object] 前画面の結果

  def running?; @running; end
  def quitted?; @exit_code.nil?.!; end
  def active_instance; player_unit.map_instance; end

  def system_unit; unit(Map::Unit::System.unit_id); end
  def player_unit; unit(Map::Unit::Player.unit_id); end
  def scroll_unit; unit(Map::Unit::Scroll.unit_id); end
  def gimmick_unit; unit(Map::Unit::Gimmick.unit_id); end
  def pointer_unit; unit(Map::Unit::Pointer.unit_id); end
  def picture_unit; unit(Map::Unit::Picture.unit_id); end
  def ui_unit; unit(Map::Unit::Ui.unit_id); end
  def interpreter_unit; unit(Map::Unit::Interpreter.unit_id); end
  def sound_unit; unit(Map::Unit::Sound.unit_id); end
  
  # @warning resuming_contextには破壊的操作が施される
  def initialize(resuming_context, view)
    super
    @resuming_context = resuming_context
    @view = view

    @x = @y = 0
    @width  = Graphics.width
    @height = Graphics.height

    @instances = []
    @notice_messages = []
    @running = true
  end
  
  def config_result(result)
    @result = result if result
    self
  end
  
  def clear_result; @result = nil if @result; end
  
  def config_position(x, y)
    @x = x
    @y = y
    self
  end

  def config_size(w, h)
    @width  = w
    @height = h
    self
  end
  
  def config_input(proc_input)
    assign_input(proc_input)
    self
  end
  
  def config_fade(fade)
    @fade = fade
    self
  end
  
  def config_sound(sound)
    @sound = sound
    self
  end
  
  def config_database(db)
    @database = db
    self
  end
  
  def config_lang(lang_msg, lang_ce)
    @lang_message = lang_msg
    @lang_common_events = lang_ce
    self
  end

  def start(map_id)
    change_state(State::Initialize, map_id)
    self
  end
  
  def quit(exit_code, exit_param = nil)
    send_signal(:change_state, Map::Unit::State::STOPPED)
    @exit_code = exit_code
    @exit_param = exit_param if exit_param
  end

  def quit_by_starting_battle(troop_id, escape, lose, event_battle = true)
    system_data = Map::SaveData::GameData.system
    map_data = active_instance.map_data

    floor = system_data.battle_floor || (map_data.specify_battleback && map_data.battleback1_name) || ""
    wall  = system_data.battle_wall  || (map_data.specify_battleback && map_data.battleback2_name) || ""

    quit(Map::ExitCode::START_BATTLE,
      :troop_id => troop_id,
      :lose     => lose,
      :escape   => escape,
      :floor_name => floor,
      :wall_name  => wall,
      :event? => event_battle,
      :gimmick => Itefu::Utility::String.note_command(:battle_gimmick=, map_data.note),
    )
  end
  
  def stop
    @running = false
  end
  
  def finalize
    stop
    finalize_animations
    clear_state
    clear_instances
    clear_all_units
    @viewports.each_value(&:dispose)
    @viewports.clear
    if @view
      @view.clear
      @view = nil
    end
  end
  
  def update
    return unless @running
    update_input
    @instances.each(&:update)
    update_units
    update_animations
    update_state
    @view.update
    @viewports.each_value(&:update)
  end
  
  def draw
    return unless @running
    @instances.each(&:draw)
    draw_units
    draw_state
    @view.draw
  end
  
  # 実行状態を保存する
  def save_to_resuming_context(context = @resuming_context)
    return unless context
    
    # 元々Map::Managerが生成したunitのだけ保存する
    mycontext = context[:manager] = {}
    (units - active_instance.units).each do |unit|
      unit.signal(:suspend, mycontext)
    end
    
    # 各マップの情報を保存する
    @instances.each do |instance|
      mycontext = context[:"map#{instance.map_id}"] = {}
      instance.suspend(mycontext)
    end
    context
  end
  
  # クイックセーブ/tempとslot1に保存する
  def quick_save
    Map::SaveData::GameData.save_map(self)
    # save to temp
    Map::SaveData::GameData.save_game
    # slot
    index = Definition::Game::Save::QUICK_SAVE_LOAD_INDEX
    Map::SaveData::GameData.save_game(index)
    if block_given?
      bitmap = yield
    else
      bitmap = Application.create_snapshot
    end
    file = Filename::SaveData::SNAPSHOT_n % index
    begin
      bitmap.export(file)
    rescue => e
      ITEFU_DEBUG_OUTPUT_ERROR e
    end
    # 今いるmapのresuming_contextは実行中は不要なので捨てる
    mycontext = @resuming_context && @resuming_context[:"map#{active_map_id}"]
    mycontext.clear if mycontext
  end

  # クイックロード用の終了処理をする
  # @note ロード処理はマップ終了後に別途行う
  def quit_to_load
    Map::SaveData::GameData.save_map(self)
    # save to temp
    Map::SaveData::GameData.save_game
    # quit to load
    quit(Map::ExitCode::LOAD)
  end


  # BGMを固定する
  def lock_bgm(value)
    system_unit.lock_bgm(value)
  end

  # 通知を予約する
  # @note 順次表示される
  def push_notice(message)
    @notice_messages << message
  end


  # 指定したマップの指定座標にプレイヤーを移動する
  def transfer(map_id, cell_x, cell_y, direction, fade_type)
    @query_transfer = {
      map_id: map_id,
      cell_x: cell_x,
      cell_y: cell_y,
      direction: direction,
      fade_type: fade_type,
    }
  end
  
  # 移動処理/演出中か？
  def transfering?; @query_transfer.nil?.!; end
  

  # --------------------------------------------------
  # Map::Instance

  def add_instance(map_id, default_cell_size = nil)
    return if @instances.any? {|instance| instance.map_id == map_id }
    # tileset_idだけは初期化前に設定しないと上書きされるものと合わせて二回ロードしてしまうことになるので先に設定する
    mycontext = @resuming_context && @resuming_context[:"map#{map_id}"]
    tileset_id = Map::Instance.tileset_id_from(mycontext)
    # マップのインスタンス生成
    instance = Map::Instance.new(self, map_id, @x, @y, @width, @height, default_cell_size, tileset_id)
    @instances << instance
    instance.setup
    # 中断した状態から再開する
    if mycontext
      instance.resume(mycontext)
      mycontext.clear
    end
    instance
  end

  def clear_instances(instance_to_keep = nil)
    activate_instance(instance_to_keep && instance_to_keep.map_id)
    @instances.delete(instance_to_keep) if instance_to_keep
    @instances.each(&:finalize)
    @instances.clear
    @instances << instance_to_keep if instance_to_keep
  end
  
  def instance_loaded?(map_id)
    @instances.any? {|instance| instance.map_id == map_id }
  end
  
  def activate_instance(map_id)
    return if @active_map_id == map_id

    # activateするとinstanceのunitsがmanagerに追加されるので
    # 先にdeactivateしてunitsを外す
    active = active_instance
    active.active = false if active

    # activation
    @active_map_id = map_id
    @instances.find do |instance|
      if (instance.map_id == map_id)
        instance.active = true
      end
    end
  end
  
  # activateしたMap::Instanceからcallbackされる
  def instance_activated(instance)
    player_unit.replace_to_new_map(instance, instance.map_viewport)
    pointer_unit.assign_viewport(instance.map_viewport)
    system_unit.play_map_sound(instance.map_data)
  end
  
  # 指定したマップインスタンスが存在すればそれを返す
  def find_instance(map_id)
    @instances.find {|instance| instance.map_id == map_id }
  end


  # --------------------------------------------------
  # Initialize

  def on_state_initialize_attach(map_id)
    @viewports = {
      picture:  Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Map::Viewport::PICTURE },
      window:   Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Map::Viewport::WINDOW },
      hud:      Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Map::Viewport::HUD },
    }
    @view.viewport = @viewports[:window]
    @view.effect_viewport = @viewports[:hud]
    
    add_unit(Map::Unit::System)
    add_unit(Map::Unit::Ui, @viewports[:hud], @viewports[:window], @view)
    add_unit(Map::Unit::Pointer)
    add_unit(Map::Unit::Picture, @viewports[:picture])
    add_unit(Map::Unit::Interpreter)
    add_unit(Map::Unit::Sound)
    add_unit(Map::Unit::Player)
   
    setup_input
    add_instance(map_id)
    change_state(State::WaitForInstance, map_id)
  end

  # --------------------------------------------------
  # WaitForInstance
  
  def on_state_wait_for_instance_attach(map_id)
    state_work[:map_id_to_start] = map_id
    ui_unit.hide_map_name
  end
  
  def on_state_wait_for_instance_update
    #　生成したインスタンスの準備が完了するのを待つ
    if @instances.all?(&:ready?)
      change_state(State::ResolveTransfering)
    end
  end
  
  def on_state_wait_for_instance_detach
    return unless running?

    # 初回起動時のみの処理
    unless @initialized
      @initialized = true
      # 中断データがある場合は復帰させる
      if @resuming_context && mycontext = @resuming_context[:manager]
        send_signal(:resume, mycontext)
        mycontext.clear
      end
    end

    # マップ処理を開始
    activate_instance(state_work[:map_id_to_start])
    @map_id_to_transfer = nil
    send_signal(:change_state, Map::Unit::State::STARTED)
    @instances.each(&:enter_to_main)
  end

  # --------------------------------------------------
  # ResolveTransfering
  
  def on_state_resolve_transfering_attach
    if @query_transfer
      player_unit.move_map(@query_transfer[:cell_x], @query_transfer[:cell_y], @query_transfer[:direction], @fade.fade_type == Itefu::Fade::Manager::FadeType::TRANSITION)
    end
    state_work[:counter] = 1
  end

  def on_state_resolve_transfering_update
    return unless (state_work[:counter] -= 1) < 0
    change_state(State::Main)
  end

  def on_state_resolve_transfering_detach
    return unless running?
    Graphics.frame_reset 
    unless @query_transfer && @query_transfer[:fade_type].nil?
      @fade.resolve if @fade && @fade.faded_out?
    end
    if @query_transfer
      map_name = active_instance.map_name
      if map_name && map_name.empty?.!
        ui_unit.show_map_name(map_name)
      end
    end
    @query_transfer = nil

    send_signal(:change_state, Map::Unit::State::OPENED)
  end

  
  # --------------------------------------------------
  # Main
  
  def on_state_main_update
    case
    when @exit_code
      change_state(State::Quit)
    when @query_transfer
      change_state(State::Transfer)
    else
      process_notice
    end
  end

  def process_notice
    return unless ui = ui_unit
    return if ui.notice_showing?
    return if (active = active_instance) && active.no_notice

    mes = @notice_messages.shift
    case mes
    when Symbol
      mes = lang_message.text(mes)
    end

    if mes
      ui.show_notice mes
    end
  end
  
  # --------------------------------------------------
  # Transfer

  def on_state_transfer_attach
    state_work[:counter] = 0

    if @fade && @fade.faded_out?.!
      case @query_transfer[:fade_type]
      when Itefu::Rgss3::Definition::Event::FadeType::NORMAL
        @fade.fade_out(15, 15)
      when Itefu::Rgss3::Definition::Event::FadeType::WHITE
        @fade.fade_color(Itefu::Color.White, 15, 15)
        state_work[:counter] = 15
      when Itefu::Rgss3::Definition::Event::FadeType::NONE
        if @query_transfer[:map_id] != active_map_id
          @fade.transit(10)
        end
      end
    elsif @query_transfer[:fade_type] == Itefu::Rgss3::Definition::Event::FadeType::NONE
      @query_transfer[:fade_type] = nil
    end

    if @fade.faded_out?
      # マップ移動時にリセットされる設定
      Map::SaveData::GameData.system.battle_floor  = 
        Map::SaveData::GameData.system.battle_wall = nil
    else
      if @query_transfer
        player_unit.move_map(@query_transfer[:cell_x], @query_transfer[:cell_y], @query_transfer[:direction], @fade && (@fade.faded_out?.! || @fade.fade_type == Itefu::Fade::Manager::FadeType::TRANSITION))
        @query_transfer = nil
      end
      change_state(State::Main)
    end
  end
    
  def on_state_transfer_update
    return unless (state_work[:counter] -= 1) < 0

    map_id = @query_transfer[:map_id]
    if instance_loaded?(map_id)
      # 読み込み済みのインスタンスに切り替える
      activate_instance(map_id)
      change_state(State::ResolveTransfering)
    else
      # 今のインスタンスを破棄して新しいインスタンスを読み込む
      send_signal(:change_state, Map::Unit::State::STOPPED)
      @map_id_to_transfer = map_id
      clear_instances
      add_instance(map_id)
      change_state(State::WaitForInstance, map_id)
    end
  end

  # --------------------------------------------------
  # Quit

  def on_state_quit_attach
    stop
  end

end

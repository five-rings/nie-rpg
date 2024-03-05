=begin
=end
class Battle::Manager
  include Itefu::Utility::State::Context
  include Itefu::Unit::Manager
  include Itefu::Animation::Player
  include Layout::View

  attr_reader :result, :exit_code
  attr_reader :losable
  attr_reader :escapable

  attr_reader :fade
  attr_reader :sound
  attr_reader :database
  attr_reader :lang_message
  attr_reader :lang_troop
  attr_reader :lang_common_events

  attr_reader :party, :troop
  attr_reader :turn_count

  def running?; @running; end
  def quitted?; @exit_code.nil?.!; end

  def interpreter_unit; unit(Battle::Unit::Interpreter.unit_id); end
  def command_unit; unit(Battle::Unit::Command.unit_id); end
  def action_unit; unit(Battle::Unit::Action.unit_id); end
  def status_unit; unit(Battle::Unit::Status.unit_id); end
  def voice_unit; unit(Battle::Unit::Voice.unit_id); end
  def party_unit; unit(Battle::Unit::Party.unit_id); end
  def troop_unit; unit(Battle::Unit::Troop.unit_id); end
  def damage_unit; unit(Battle::Unit::Damage.unit_id); end
  def picture_unit; unit(Battle::Unit::Picture.unit_id); end
  def gimmick_unit; unit(Battle::Unit::Gimmick.unit_id); end
  def field_unit; unit(Battle::Unit::Field.unit_id); end
  def message_unit; unit(Battle::Unit::Message.unit_id); end
  def result_unit; unit(Battle::Unit::Result.unit_id); end

  def effect_viewport; @viewports[:hud]; end

  def initialize(troop_id, escape, lose, event_battle = true)
    super
    @result = Battle::Result.new(event_battle)
    @losable = lose
    @escapable = escape
    @running = true

    @x = @y = 0
    @width  = Graphics.width
    @height = Graphics.height

    @party = Battle::Party.new
    @troop = Battle::Troop.new(troop_id, @width)
    @booty = Game::Agency::Booty.new
    @turn_count = @turn_end_count = 0
    Battle::SaveData::GameData.flags.turn_count = @turn_count
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

  def config_lang(lang_msg, lang_trp, lang_ce)
    @lang_message = lang_msg
    @lang_troop = lang_trp
    @lang_common_events = lang_ce
    self
  end

  def start(floor_name, wall_name, bgm, gimmick = nil)
    change_state(State::Initialize, floor_name, wall_name, bgm, gimmick)
    self
  end

  def quit(exit_code, outcome = nil)
    @exit_code = exit_code
    @result.outcome = outcome if outcome
  end

#ifdef :ITEFU_DEVELOP
  def kill_all_enemies
    @sound.play_enemy_damage_se
    @troop.enemies.each(&:die)
  end
#endif

  def stop
    @running = false
  end

  def finalize
    stop
    finalize_layout
    finalize_animations
    clear_state
    clear_all_units
    @viewports.each_value(&:dispose)
    @viewports.clear
  end

  def update
    return unless running?
    # update_input
    update_units
    # update_animations
    update_state
    update_layout
    @viewports.each_value(&:update)
  end

  def draw
    return unless running?
    draw_units
    draw_state
    draw_layout
  end

  def increase_turn
    reset_turn_action
    interpreter_unit.reset_turn_event
    @turn_count += 1
    Battle::SaveData::GameData.flags.turn_count = @turn_count
  end

  def process_event(turn_end, state_to_go_back = nil)
    if interpreter_unit.trigger_event(turn_end)
      change_state(State::Event, state_to_go_back || state)
      true
    end
  end

  # 装備の効果で自動で適用されるステートの処理
  def apply_auto_state
    party_unit.units.each do |actor_unit|
      actor_unit.apply_auto_state(@turn_count)
    end
  end

  def apply_auto_skill
    party_unit.units.each do |actor_unit|
      actor_unit.apply_auto_skill(@turn_count)
    end
  end

  def regenerate
    troop_unit.units.each do |enemy_unit|
      apply_regenerate(enemy_unit)
    end
    party_unit.units.each do |actor_unit|
      apply_regenerate(actor_unit)
    end
  end

  def add_party_member(actor_id, init)
    @party.add_actor(actor_id)
    party_unit.lazy_sort { party_unit.add_actor }
  end

  def event_damage(dmg, target_status, rate = 1)
    dtype = Game::Agency::DamageType.new(false, false, false)
    action_hp_damage(nil, dmg, nil, target_status, nil, rate, dtype)
    target_status.add_hp(-dmg)
  end

  def event_state(state_id, target_status, rate = 1)
    # ステートを耐性値を考慮して付与し
    # 成功したらラベルを出す
    @dummy_damage ||= Game::Agency::Damage.new
    # @memo change=1.0なのでMISS(ret=nil)にはならない
    ret = @dummy_damage.apply_state(target_status, nil, state_id, 1.0)
    action_add_state(nil, state_id, ret, nil, target_status, nil, rate)
    # 前述によりMISSにはならないので@damage_data[:miss_state]の処理は不要
  end

  def check_battle_finish
    result = @result.outcome
    result ||= case
               when troop_unit.wiped_out?
                 Itefu::Rgss3::Definition::Event::Battle::Result::WIN
               when party_unit.wiped_out?
                 Itefu::Rgss3::Definition::Event::Battle::Result::LOSE
               when party_unit.escaped?
                 Itefu::Rgss3::Definition::Event::Battle::Result::ESCAPE
               end
    case result
    when Itefu::Rgss3::Definition::Event::Battle::Result::WIN
      unless process_event(nil, State::Winning)
        change_state(State::Winning)
      end
    when Itefu::Rgss3::Definition::Event::Battle::Result::LOSE
      unless process_event(nil, State::Losing)
        change_state(Itefu::Utility::State::Wait, 45, State::Losing)
      end
    when Itefu::Rgss3::Definition::Event::Battle::Result::ESCAPE
      unless process_event(nil, State::Escaping)
        change_state(State::Escaping)
      end
    else
      return false
    end
    @result.outcome = result
    true
  end

  # --------------------------------------------------
  # Initialize

  def on_state_initialize_attach(floor_name, wall_name, bgm, gimmick = nil)
    @viewports = {
      window:   Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Battle::Viewport::WINDOW },
      hud:      Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Battle::Viewport::HUD },
      battler:  Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Battle::Viewport::BATTLER },
      result:  Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Battle::Viewport::RESULT },
      label:  Itefu::Rgss3::Viewport.new(@x, @y, @width, @height).tap {|vp| vp.visible = true; vp.z = Battle::Viewport::LABEL },
    }

    add_unit(Battle::Unit::Field, @viewports[:battler], floor_name, wall_name)

    add_unit(Battle::Unit::Gimmick, @viewports[:battler]).tap do |unit|
      # 初期設定されているギミックの適用
      if gimmick
        gimmick, *params = gimmick.split(",")
        if gimmick
          params.map! {|p| Itefu::Utility::String.to_number(p) }
          unit.change_additional_gimmick(gimmick, *params)
          unit.update
        end
      end
    end

    change_state(State::Opening, bgm)
  end

  def on_state_initialize_detach
    if @fade.faded_out?
      @sound.stop_me
      @sound.play_battle_start_se
      @fade.resolve
    end
  end

  # --------------------------------------------------
  # Opening

  def on_state_opening_attach(bgm)
    @party.setup_from_savedata(Application.savedata_game)
    @troop.setup_from_database(@database.troops, @database.enemies)

    load_layout("battle/base")
    add_unit(Battle::Unit::Interpreter)
    add_unit(Battle::Unit::Picture, @viewports[:hud])
    add_unit(Battle::Unit::Status, @viewports[:hud])
    add_unit(Battle::Unit::Action, @viewports[:hud])
    add_unit(Battle::Unit::Command, @viewports[:window])
    add_unit(Battle::Unit::Party, @party, @viewports[:battler], @viewports[:label])
    add_unit(Battle::Unit::Troop, @troop, @viewports[:battler], @viewports[:label])
    add_unit(Battle::Unit::Voice, @viewports[:label])
    add_unit(Battle::Unit::Damage, @viewports[:label])
    add_unit(Battle::Unit::Message, @viewports[:window])
    add_unit(Battle::Unit::Result, @viewports[:result])
    if @sound
      @sound.play(bgm)
      @sound.stop_bgs
    end
    Graphics.frame_reset
    layout_imported
    state_work[:counter] = 30
  end

  def on_state_opening_update
    return if status_unit.unit_state != Battle::Unit::State::OPENED
    return if (state_work[:counter] -= 1) > 0
    change_state(State::Command)
  end

  def on_state_opening_detach
    send_signal(:change_state, Battle::Unit::State::STARTED)
  end

  # --------------------------------------------------
  # Command

  def on_state_command_attach
#ifdef :ITEFU_DEVELOP
    # テストプレイ用機能などで強制的に敵を倒すとここで終了し得る
    return if check_battle_finish
#endif
    # 0ターンイベントorターン終了時のイベント
    return if process_event(@turn_count != 0)
    # ターン開始時の自動処理
    apply_auto_skill
    apply_auto_state


    increase_turn
    ITEFU_DEBUG_OUTPUT_NOTICE "start commanding (turn: #{@turn_count})"
    send_signal(:change_state, Battle::Unit::State::COMMANDING)

    # 敵の行動を決定
    au = action_unit
    troop_unit.units.each do |enemy|
      enemy.make_actions(au)
    end
    # 制御不能な味方の行動を決定
    party_unit.units.each do |actor|
      actor.make_action(au)
    end
    au.update_action_list

    # コマンド選択を開始する
    command_unit.start_command(0)
  end

  def on_state_command_update
#ifdef :ITEFU_DEVELOP
    # テストプレイ用機能などで強制的に敵を倒すとここで終了し得る
    return if check_battle_finish
#endif
    return if command_unit.unit_state != Battle::Unit::State::COMMANDED
    change_state(Itefu::Utility::State::Wait, 15, State::Prepare)
  end

  def on_state_command_detach
#ifdef :ITEFU_DEVELOP
    if running? && command_unit.unit_state != Battle::Unit::State::COMMANDED
      clear_focus
      if control(:command_menu_window).openness != 0
        play_animation(:command_menu_window, :out)
      end
    end
#endif
    if command_unit.unit_state == Battle::Unit::State::COMMANDED
      # コマンド確定時
      action_unit.confirm_action
      party_unit.units.each do |unit|
        unit.memo_using_skill(action_unit.find_action(unit))
      end
      status_unit.active_all
    end
  end

  # --------------------------------------------------
  # Event
  def on_state_event_attach(state_back_to)
    state_work[:back_to] = state_back_to
  end

  def on_state_event_update
    return if interpreter_unit.running?

    case
    when quitted?
      change_state(State::Quit)
    else
      change_state(state_work[:back_to])
    end
  end

  def on_state_event_detach
  end

  # --------------------------------------------------
  # Prepare
  def on_state_prepare_attach
    send_signal(:change_state, Battle::Unit::State::IN_ACTION)
    # ターン中のイベント
    # デフォルト実装ではターン開始or終了時のみのチェックだが行動ごとにチェックする
    return if process_event(false)

    # 優先度の高いアクションを取得する
    while action = action_unit.pop_action
      break if action.subject.available? # && action.subject.movable?
      action_unit.update_action_list
    end

    if action
      pre_process_action(action)

      # 複数回行動
      if action.item && action.additional_move_count > 0
        action.additional_move_count -= 1
        action_unit.push_action action
      end

      # アクション名を使用者の上に表示する
      voice_unit.show(action.label, action.subject)
      change_state(Itefu::Utility::State::Wait, 15, State::Action, action)
    else
      change_state(State::TurnEnd)
    end
  end

  # --------------------------------------------------
  # Action

  def on_state_action_attach(action = nil)
    if action
      process_action(action)
      # show attacking animation at least 60 frames
      state_work[:counter] = 60
    end
    state_work[:action] = action
  end

  def on_state_action_update
    state_work[:counter] -= 1
    return if processing_action?
    return if playing_animation?(:action_effect)
    return if state_work[:counter] >= 0
    process_action_finished(state_work[:action])

    # アクション完了後の特殊動作
    party_unit.units.each do |actor_unit|
      actor_unit.post_action
      if interpreter_unit.running?
        # イベント実行の場合はそちらを優先する
        return change_state(State::Event, state)
      end
    end

    # 戦闘の終了判定
    unless check_battle_finish
      # 次の行動へ
      if action_unit.empty?
        change_state(State::TurnEnd)
      else
        change_state(Itefu::Utility::State::Wait, 15, State::Prepare)
      end
    end
  end

  def on_state_action_detach
    state_work[:action] = nil
    voice_unit.close
    action_unit.update_action_list
  end

  # --------------------------------------------------
  # TurnEnd

  def turn_ended?; @turn_end_count == @turn_count; end

  def on_state_turn_end_attach
    unless turn_ended?
      @turn_end_count = @turn_count
      send_signal(:change_state, Battle::Unit::State::TURN_END)
    end

    # ターン終了時に発生したアクションを処理する
    if action_unit.empty?
      change_state(Itefu::Utility::State::Wait, 30, State::PostTurn)
    else
      change_state(Itefu::Utility::State::Wait, 15, State::Prepare)
    end
  end

  # --------------------------------------------------
  # PostTurn

  def on_state_post_turn_attach
    regenerate
    state_work[:counter] = 0
  end

  def on_state_post_turn_update
    state_work[:counter] += 1
    if playing_animations?
      return if state_work[:counter] <= 30
    else
      return if state_work[:counter] <= 1
    end

    unless check_battle_finish
      change_state(State::Command)
    end
  end

  def on_state_post_turn_detach
  end

  # --------------------------------------------------
  # Winning

  def on_state_winning_attach
    send_signal(:change_state, Battle::Unit::State::FINISHING)
    change_state(State::Winning2)
  end

  def on_state_winning2_attach
    if troop_unit.units.any?(&:playing_dying_animation?)
      return change_state(Itefu::Utility::State::Wait, 1, State::Winning2)
    end

    party_unit.units.each(&:play_winning_animation)
    if @sound
      if me = Application.savedata_game.system.battle_me
        @sound.play(me)
      else
        # @todo play_battle_end_me にイベントからの変更も反映されてほしい
        @sound.play_battle_end_me
      end
      @sound.stop_bgm
    end
  end

  def on_state_winning2_update
    return if playing_animations?
    change_state(State::Result)
  end

  def on_state_winning2_detach
  end


  # --------------------------------------------------
  # Result

  def on_state_result_attach
    @troop.loot(@booty)
    result_unit.open(@booty)
  end

  def on_state_result_update
    if result_unit.closed?
      change_state(Itefu::Utility::State::Wait, 10, State::Quit)
    end
  end

  def on_state_result_detach
  end

  # --------------------------------------------------
  # Losing

  def on_state_losing_attach
    send_signal(:change_state, Battle::Unit::State::FINISHING)
    change_state(Itefu::Utility::State::Wait, 120, State::Quit)
    if @losable
      @sound.stop_bgm(1500) if @sound
    else
      @sound.play_gameover_me if @sound
    end
  end

  def on_state_losing_update
  end

  def on_state_losing_detach
  end

  # --------------------------------------------------
  # Escaping

  def on_state_escaping_attach
    send_signal(:change_state, Battle::Unit::State::FINISHING)

    case party_unit.escape_type
    when :disappear
      party_unit.units.each {|u| u.play_escaping_animation(true) }
      @sound.play_se("Starlight", 80, 100) if @sound
    else
      party_unit.units.each(&:play_escaping_animation)
      @sound.play_escape_se if @sound
    end
  end

  def on_state_escaping_update
    return if playing_animations?
    change_state(Itefu::Utility::State::Wait, 30, State::Quit)
  end

  def on_state_escaping_detach
  end

  # --------------------------------------------------
  # Quit

  def on_state_quit_attach
    if @sound
      @sound.stop_bgm
      @sound.stop_me(2000)
    end
    stop
    send_signal(:change_state, Battle::Unit::State::QUIT)
  end

end


=begin
 戦闘ｌ用のEventInterpreter 
=end
class Event::Interpreter::Battle
  include Event::Interpreter
  attr_accessor :battle_manager

  def manager; battle_manager; end
  def database; battle_manager.database; end
  def sound; battle_manager.sound; end
  def common_message; battle_manager.lang_common_events; end
  def troop_text(id, indices); text_from_message_with_id(battle_manager.lang_troop, id, indices) || ""; end
  def battle?; true; end

  def initialize(parent = nil)
    super
    if parent
      @battle_manager = parent.battle_manager
    end
  end

  # --------------------------------------------------
  # 独自実装


  # ステート付与を耐性計算の上で実施するようにする
  # @note 条件分岐のスクリプトから呼ぶと、自動で解除される
  def state_trial(conclude = false)
    if conclude
      @state_trial = nil
    else
      @state_trial = current_command.indent
    end
    true
  end

  # 条件分岐の末尾で自動解除する
  def command_412(indent, *args)
    if @state_trial == indent
      state_trial(true)
    end
    super
  end

  # --------------------------------------------------
  # アプリケーションで実装する必要のある補助機能
  
  def troop_members
    @battle_manager.troop.enemies
  end

  def enemy_instance(index)
    @battle_manager.troop.enemies[index]
  end

  def enemy_hp(enemy)
    enemy.hp
  end

  def enemy_mp(enemy)
    enemy.mp
  end

  def enemy_param(enemy, padam_id)
    enemy.param(param_id)
  end
  
  def enemy_appeared?(enemy)
    enemy_unit = battle_manager.troop_unit.find_enemy_unit(enemy)
    enemy_unit && enemy_unit.available?
  end

  def enemy_state?(enemy, state_id)
    enemy.in_state_of?(state_id)
  end


  # --------------------------------------------------
  # アプリケーションで実装する必要のあるイベントの処理

  def event_show_message(message, face_name, face_index, background, position)
    if common_event?
      msg = common_message
    else
      msg = battle_manager.lang_troop
    end

    if m = message_text(msg, message)
      message = m
    end

    message_unit = battle_manager.message_unit
    message_unit.show(message, face_name, face_index, background, position)

    event_wait until message_unit.ready?
  end

  def event_message_showing?
    battle_manager.message_unit.showing?
  end

  def event_message_closed?
    battle_manager.message_unit.window_closed?
  end

  def event_wait_101
    if event_message_showing?
      command = current_command
      background = command.parameters[2]
      position = command.parameters[3]
      # 前のメッセージが既に表示されているので、可能なら上書きする
      # 上書きできない場合は一旦閉じてから新しいメッセージを表示する
      event_wait until event_message_closed? ||
                       battle_manager.message_unit.reassignable?(background, position)
    else
      # 前のウィンドウが完全に閉じてから新しいメッセージを表示する
      event_wait until event_message_closed?
    end
  end

  def event_show_choices(choices, cancel_value)
    if common_event?
      msg = common_message
    else
      msg = battle_manager.lang_troop
    end
    choices.map!.with_index {|choice, i|
      message_text(msg, choice) || choice
    }
    battle_manager.message_unit.open_choices(choices, cancel_value) {|index|
      branch(current_command.indent, index)
    }
  end

  def event_choices_showing?
    battle_manager.message_unit.choices_showing?
  end

  def event_show_numeric_input(variable_id, digit)
    battle_manager.message_unit.open_numeric_input(digit) {|value|
     change_variable(variable_id, value)
    }
  end

  def event_numeric_input_showing?
    battle_manager.message_unit.numeric_input_showing?
  end

  # アイテム選択を表示する
  # @param [Fixnum] variable_id 選択されたアイテムのIDを受け取る「変数」のID
  def event_show_item_select(variable_id)
    raise Itefu::Exception::NotSupported
  end

  # @return [Boolean] アイテム選択を表示中か
  def event_item_select_showing?; false; end

  # スクロール文章を表示する
  # @param [String] text 表示する文章
  # @param [Fixnum] speed スクロールする速さ [0-8]
  # @param [Boolean] not_to_fast_feed 早送り無効
  def event_show_scrolling_text(text, speed, not_to_fast_feed)
    raise Itefu::Exception::NotSupported
  end

  # @return [Boolean] スクロール文章を表示中か
  def event_scrolling_text_showing?; false; end

  # 戦闘アニメーション
  def command_337(indent, params)
    if anime_data = database.animations[params[1]]
      if Itefu::Rgss3::Definition::Animation::Position.screen?(anime_data.position)
        # ターゲットを集めておいて一括で再生する
        @targets = []
      else
        @targets = nil
      end
      super
      if @targets
        anime = Itefu::Animation::Effect.new(anime_data).auto_finalize
        anime.assign_target(@targets, battle_manager.effect_viewport)
        battle_manager.play_raw_animation(anime, anime)
      end
    end
  end

  def event_play_effect_animation(enemy, anime_id)
    return super unless enemy_unit = battle_manager.troop_unit.find_enemy_unit(enemy)
    if enemy_unit.available?
      if @targets
        @targets << enemy_unit.sprite_target
      else
        if anime_data = database.animations[anime_id]
          anime = Itefu::Animation::Effect.new(anime_data).auto_finalize
          anime.assign_target(enemy_unit.sprite_target, battle_manager.effect_viewport)
          battle_manager.play_raw_animation(anime, anime)
        end
      end
    end
  end

  def event_effect_animation_playing?(enemy)
    # 戦闘アニメはたきっぱなし
    false
  end

  def event_change_battle_bgm(bgm)
    battle_manager.sound.play(bgm)
    super
  end

  def event_change_tone(tone, duration)
    battle_manager.gimmick_unit.change_tone(tone, duration)
  end

  def event_flash(color, duration)
    battle_manager.gimmick_unit.flash(color, duration)
  end

  def event_shake(power, speed, duration)
    battle_manager.gimmick_unit.shake(power, speed, duration)
  end

  def event_show_picture(index, name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
    battle_manager.picture_unit.show(index, name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
  end

  def event_move_picture(index, origin, x, y, zoom_x, zoom_y, opacity, blend_type, duration)
    battle_manager.picture_unit.move(index, origin, x, y, zoom_x, zoom_y, opacity, blend_type, duration)
  end

  def event_rotate_picture(index, angle)
    battle_manager.picture_unit.rotate(index, angle)
  end

  def event_change_picture_tone(index, tone, duration)
    battle_manager.picture_unit.change_tone(index, tone, duration)
  end

  def event_erase_picture(index)
    battle_manager.picture_unit.erase(index)
  end

  def event_change_weather(weather_type, power, duration, *args)
    battle_manager.gimmick_unit.change_weather(weather_type, power, duration, *args)
  end

  def event_change_battle_background(back1, back2)
    super
    battle_manager.fade.transit(15)
    battle_manager.field_unit.change(back1, back2)
    battle_manager.fade.resolve
  end

  def event_change_actor_graphic(actor, chara_name, chara_index, face_name, face_index)
    super
    # 戦闘画面に表示中のグラフィックスも変更する
    battle_manager.status_unit.update_graphic
    if actor_unit = battle_manager.party_unit.find_actor_unit(actor)
      actor_unit.update_graphic(chara_name, chara_index)
    end
  end

  def event_add_enemy_hp(enemy, diff, to_die)
    enemy.add_hp(diff, to_die.!)
  end

  def event_add_enemy_mp(enemy, value)
    enemy.add_mp(diff)
  end

  def event_append_actor_state(actor, state_id)
    if @state_trial
      battle_manager.event_state(state_id, actor)
    else
      super
    end
  end

  def event_append_enemy_state(enemy, state_id)
    if @state_trial
      battle_manager.event_state(state_id, enemy)
    else
      enemy.add_state(state_id, true)
    end
  end

  def event_remove_enemy_state(enemy, state_id)
    enemy.remove_state(state_id)
  end

  def event_recover_enemy(enemy)
    enemy.recover_all
  end

  def event_make_enemy_appear(enemy)
    if enemy_unit = battle_manager.troop_unit.find_enemy_unit(enemy)
      enemy_unit.appear
    end
  end

  def event_make_enemy_transform(enemy, enemy_id)
    if enemy_unit = battle_manager.troop_unit.find_enemy_unit(enemy)
      enemy_unit.transform(enemy_id)
    end
  end

  def event_force_actor_take_action(actor, skill_id, target_index)
    return unless skill = database.skills[skill_id]
    return unless actor_unit = battle_manager.party_unit.find_actor_unit(actor)
    battle_manager.force_action(actor_unit, skill, target_index)
  end


  def event_force_enemy_take_action(enemy, skill_id, target_index)
    return unless skill = database.skills[skill_id]
    return unless enemy_unit = battle_manager.troop_unit.find_enemy_unit(enemy)
    battle_manager.force_action(enemy_unit, skill, target_index)
  end

  def event_actor_being_in_action?(actor); false; end
  def event_enemy_being_in_action?(enemy); false; end

  # 戦闘を中断する
  def event_abort_battle
    result = battle_manager.escapable ?  Itefu::Rgss3::Definition::Event::Battle::Result::ESCAPE : Itefu::Rgss3::Definition::Event::Battle::Result::WIN
    battle_manager.quit(
      ::Battle::ExitCode::BATTLE_FINISHED,
      result
    )
  end

  # 戦闘の中断処理を行っている最中か
  def event_aborting_battle?
    event_message_showing? || event_message_closed?.!
  end

  # ゲームオーバー画面に移動する
  def event_game_over
    SaveData.reset
    battle_manager.quit(::Battle::ExitCode::CLOSE)
  end

  # タイトル画面に移動する
  def event_go_to_title
    SaveData.reset
    battle_manager.quit(::Battle::ExitCode::CLOSE)
  end

  def event_join_party(actor_id, init)
    super
    battle_manager.add_party_member(actor_id, init)
  end

  # @return [Boolean] 帰還できる場所があるか
  def fairy_home?
    return false unless battle_manager.escapable
    return false unless fairy_home_point
    true
  end

  # 妖精帰還での帰還先のマップ名
  def map_name_of_fairy_home
    name = SaveData.collection.name_of_home_place(fairy_home_point)
    if name.nil? || name.empty?
      msg = battle_manager.lang_message
      msg && msg.text(:unknown_home_point) || ""
    else
      name
    end
  end

  # 妖精帰還で参照するマップID
  def fairy_map_id
    SaveData.map.fairy_map_id || SaveData.map.map_id
  end

  # 妖精帰還する帰還先
  def fairy_home_point
    if SaveData.system.to_go_home
      # 通常時は最後にアクセスした妖精の集いへ帰れる
      SaveData.collection.home_point
    else
      # 帰還アイテム禁止区域でも、同一マップの妖精の集いへの帰還はできる
      cell_x, cell_y = SaveData.map.cell_xy_from_resuming_context
      return unless cell_x && cell_y
      SaveData.collection.home_point_nearest(fairy_map_id, cell_x, cell_y)
    end
  end

  # 帰還場所に移動する
  def move_to_fairy_home
    return unless point = fairy_home_point

    # パーティを無理やり先頭キャラの位置に合わせる
    # cell_x, cell_y = SaveData.map.cell_xy_from_resuming_context
    # SaveData.map.setup_start_position(cell_x, cell_y, Itefu::Rgss3::Definition::Direction::NOP)

    event = RPG::CommonEvent.new
    if point[:map_id] == SaveData.map.map_id
      event.list.unshift RPG::EventCommand.new(222) # フェードイン
      event.list.unshift RPG::EventCommand.new(355, 0, ["move_to_fairy_home"])
      event.list.unshift RPG::EventCommand.new(221) # フェードアウト
      event.list.unshift RPG::EventCommand.new(230, 0, [30])  # ウェイト
    else
      event.list.unshift RPG::EventCommand.new(355, 0, ["move_to_fairy_home"])
      event.list.unshift RPG::EventCommand.new(230, 0, [10])  # ウェイト
      event.list.unshift RPG::EventCommand.new(217) # 集合
    end
    # スイッチで中断できるようにする
    event.list.unshift RPG::EventCommand.new(412) # endif
      event.list.unshift RPG::EventCommand.new(121, 1, [11, 11, 1]) # change_switch(11, false)
    event.list.unshift RPG::EventCommand.new(411) # else
      event.list.unshift RPG::EventCommand.new(115, 1) # イベント処理の中断
    event.list.unshift RPG::EventCommand.new(111, 0, [0, 11, 1]) # if switch[11] == OFF

    change_switch(11, true)

    # マップに戻ったら自動でイベントを実行する
    context = SaveData.map.resuming_context[:manager][::Map::Unit::System.unit_id]
    context[:events] ||= []
    context[:events] << event

    # 消える演出で逃げる
    battle_manager.party_unit.escape(:disappear)
  end

end

=begin
=end
class Battle::Manager

  ActionAnimeContext = Struct.new(:action, :applied, :targets, :count)

  def force_action_target(subject, skill, target_index)
    target = case skill.scope
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_OPPONENTS
        subject.opponent_unit.make_target_all
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_FRIENDS
        subject.friend_unit.make_target_all
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_DEAD_FRIENDS
        subject.friend_unit.make_target_all_dead
      when Itefu::Rgss3::Definition::Skill::Scope::MYSELF
        subject.make_target
      when Itefu::Rgss3::Definition::Skill::Scope::NONE
        @action_none ||= proc { [] }
      else
        if 1 < count = Itefu::Rgss3::Definition::Skill::Scope.random_count(skill.scope)
          subject.opponent_unit.make_target_random(count)
        end
      end

    target ||= case target_index
      when Itefu::Rgss3::Definition::Event::Battle::Target::LAST_CURSOR
        raise Itefu::Exception::NotSupported
      when Itefu::Rgss3::Definition::Event::Battle::Target::RANDOM
        if Itefu::Rgss3::Definition::Skill::Scope.to_opponent?(skill.scope)
          subject.opponent_unit.make_target_random(1)
        else
          if Itefu::Rgss3::Definition::Skill::Scope.to_dead?(skill.scope)
            subject.friend_unit.make_target_random_dead(1)
          else
            subject.friend_unit.make_target_random(1)
          end
        end
      else
        if Itefu::Rgss3::Definition::Skill::Scope.to_opponent?(skill.scope)
          subject.opponent_unit.make_target(target_index)
        else
          subject.friend_unit.make_target(target_index)
        end
      end

    target
  end

  def force_action(subject, skill, target_index)
    target = force_action_target(subject, skill, target_index)

    unless action = action_unit.replace_action(subject, skill, target)
      speed = Float::INFINITY # 差し替えなしの場合は先頭に積む
      action = action_unit.add_action(subject, target, skill, subject.icon_index, subject.icon_label, skill.name, speed)
    end
    action
  end
  
  def force_add_action(subject, skill, target_index)
    target = force_action_target(subject, skill, target_index)
    speed = Float::INFINITY # 先頭に積む
    action_unit.add_action(subject, target, skill, subject.icon_index, subject.icon_label, skill.name, speed)
  end

  def pre_process_action(action)
    # 状態異常の場合のキャンセル処理
    action.states && action.states.each do |state|
      next unless Itefu::Rgss3::Definition::State::Restriction.uncontrollable?(state) && action.subject.status.in_state_of?(state.id)

      action.subject.nullify_action_by_state_restriction(action, state)
      break
    end
  end

  def process_action(action)
    target = action.target.call
    if target.empty?
      add_cancel_action(action.subject)
      return
    end

    item = action.item
    case item
    when nil
      add_cancel_action(action.subject)
    when RPG::Item
      if @party.number_of_item(item.id) >= 1 && @party.consume_item_if_possible(item, 1)
        # アイテムを使用
        play_action_animation(action, target)
      else
        # アイテムが足りない
        add_miss_action(action.subject)
      end
    when RPG::Skill
      unless action.subject.status.skill_usable?(item)
        # スキル封印
        return add_miss_action(action.subject)
      end
      if action.subject.has_inventory? && (medium_id = item.medium_id)
        # 触媒アイテムが足りるかチェック
        medium_num = item.medium_num
        if medium_num > @party.number_of_item(medium_id)
          # 触媒アイテムが足りない
          return add_miss_action(action.subject)
        end
      end
      if item.use_all_mp?
        cost = action.subject.status.mp
      else
        cost = item.mp_cost
      end
      if turn_ended? || action.subject.consume_mp_if_possible(cost)
        # 触媒アイテムを消費
        if medium_id
          # @note 仮に敵が触媒を必要とするならsubjectに応じて処理を分けないといけない
          @party.consume_item_by_id(medium_id, medium_num)
        end
        # スキルを見切る
        process_proving_action(action.subject, target, item.id, action)
        # スキルを使用
        play_action_animation(action, target)
      else
        # MPが足りない
        add_miss_action(action.subject)
      end
    when RPG::UsableItem
      # スキル/アイテムを使用
      play_action_animation(action, target)
    when RPG::EquipItem
      # 装備変更
      # @magic 装備変更用アニメid, 演出用の微調整
      play_action_animation(action, target, 110, 5, true, 0.2)
    else
      # 謎の行動
      ITEFU_DEBUG_OUTPUT_WARNING "Unknown action.item #{item} of #{action.subject}(#{action.subject.unit_id})"
    end
  end

  def processing_action?
    playing_animation?(:action_effect) ||
    interpreter_unit.running?
  end

  def reset_turn_action
    @actioned ||= {}
    @actioned.clear
  end

  def process_action_finished(action)
    return unless action
    subject = action.subject
    user_status = subject.status

    unless @actioned[subject]
      user_status.ease_states_due_to_timing(Itefu::Rgss3::Definition::State::AutoRemovalTiming::ACTION)
      user_status.remove_states_due_to_eased_out {|state|
        push_chain_skill_by_state(subject, state)
        true
      }
      @actioned[subject] = true
    end
  end

  def process_proving_action(subject, objects, skill_id, action)
    if action.unrevealed?
      if objects.any? {|target| subject.reveal_skill(target, skill_id) }
        action_unit.reveal_action(action.item)
        # @sound.play_se("Hammer", 100, 150) if @sound
      end
    end
  end

  def play_action_animation(action, target, anime_id = nil, speed = nil, blind = nil, zoom = nil)
    db_anime = @database.animations
    anime_id ||= action.item.animation_id
    anime_id = action.subject.status.attack_animation_id if anime_id == -1 # @magic 通常攻撃のアニメーションを使う
    return apply_action(nil, action) unless anime_data = db_anime[anime_id]
    viewport = effect_viewport

    objects = target || action.target.call

    anime = Itefu::Animation::Effect.new(anime_data)
    anime.play_speed = speed if speed
    anime.blind(blind) if blind
    anime.zoom(zoom, zoom) if zoom
    anime.called_empty_timing = method(:apply_action)
    anime.context = ActionAnimeContext.new(action, false, objects)

    if Itefu::Rgss3::Definition::Animation::Position.screen?(anime_data.position)
      # 一つエフェクトをたいてターゲットを複数指定する
      anime.assign_target(objects.map(&:sprite_target), viewport)
      if Battle::Unit::Actor === objects.first
        # @magic 全体攻撃が味方に当たるようにすこしずらして表示する
        anime.offset(nil, 120)
      end
      anime.finisher {|a|
        apply_action(a, a.context.action)
      }.auto_finalize
    else
      # 複数のターゲットに対して順次適用する
      target = objects.first
      anime.context.count = 0
      anime.assign_target(target.sprite_target, viewport)
      zoom ||= 1.0
      anime.zoom(zoom * target.effect_scale, zoom * target.effect_scale)

      anime.starter {|a|
        a.context.applied = false
      }.finisher {|a|
        apply_action(a, a.context.action)

        # ターゲットが残っていればもう一度再生する
        a.context.count += 1
        if target = a.context.targets[a.context.count]
          a.assign_target(target.sprite_target, viewport)
          a.zoom(zoom * target.effect_scale, zoom * target.effect_scale)
          play_raw_animation(:action_effect, a)
        else
          a.auto_finalize
        end
      }
    end

    play_raw_animation(:action_effect, anime)
  end

  # 行動ダメージが発生した際に行動リストにエフェクトを発生させる
  def play_action_damage_animation(action)
    return if playing_animation?(:action_damage) || reserved_animation(:action_damage)
    return unless target = action_unit.action_control(action)
    db_anime = @database.animations
    return unless anime_data = db_anime[116] # @magic: 行動ダメージ演出
    anime = Itefu::Animation::Effect.new(anime_data)
    anime.assign_target(target.sprite, effect_viewport)
    anime.offset_z(0xff)
    anime.auto_finalize
    play_raw_animation(:action_damage, anime)
  end

  def apply_action(anime, action = nil)
    return if anime && anime.context.applied
    # @need_to_call_damage_se = action.nil?.!
    @need_to_call_damage_se = true

    action ||= anime.context.action
    targets = anime && anime.context.targets || action.target.call

    if c = anime && anime.context.count
      if target = targets[c]
        apply_action_effect(action.subject, action.item, target)
      end
    else
      targets.each do |target|
        apply_action_effect(action.subject, action.item, target)
      end
    end

    # skill chaining
    if chains = action.item.special_flag(:chain)
      subject = action.subject
      scope = action.item.scope
      chains.each do |id|
        next unless s = database.skills[id]
        case s.scope == scope && s.scope
        when Itefu::Rgss3::Definition::Skill::Scope::OPPONENT,
             Itefu::Rgss3::Definition::Skill::Scope::FRIEND,
             Itefu::Rgss3::Definition::Skill::Scope::DEAD_FRIEND
          # 元のスキルのターゲットを維持する
          ts = targets
        else
          # 指定スキルの効果範囲に応じて選ぶ
          ts = subject.make_target_by_skill(s)
          next unless ts = ts && ts.call
        end
        ts.each do |t|
          apply_action_effect(subject, s, t)
        end
      end
    end

    @need_to_call_damage_se = false
    anime.context.applied = true if anime
  end

  def apply_action_effect(subject, item, target)
    user_status = subject.status
    target_status = target.status

    case item
    when RPG::EquipItem
      old = @party.change_equipment(target.unit_id, item)
      target.remove_auto_state(old) if old
      target.apply_auto_state_item(0, item)
      subject.status.add_state(4) # @magic: 防御を付与する
    when RPG::UsableItem
      unless @agent
        @agent = Game::Agency::Damage.new
        @agent.add_callback(:miss, method(:action_miss))
        @agent.add_callback(:hp_damage, method(:action_hp_damage))
        @agent.add_callback(:hp_drain, method(:action_hp_drain))
        @agent.add_callback(:mp_damage, method(:action_mp_damage))
        @agent.add_callback(:mp_drain, method(:action_mp_drain))
        @agent.add_callback(:add_state, method(:action_add_state))
        @agent.add_callback(:remove_state, method(:action_remove_state))
        @agent.add_callback(:effect_applied, method(:action_effect_applied))
        @agent.add_callback(:state_eased, method(:action_state_eased))
        @agent.add_callback(:special, method(:action_special))
        @agent.add_callback(:common_event, method(:action_common_event))
        @agent.add_callback(:note, method(:action_note))
      end
      @damage_work ||= {}
      @damage_work.clear
      @agent.apply_item(user_status, target_status, item)
    end
  end

  # ステートが切れた際に発動するスキルを追加する
  def push_chain_skill_by_state(subject, state)
    return unless chains = state.special_flag(:chain)
    chains.split(",").reverse_each do |chain|
      next unless id = Integer(chain) rescue nil
      next unless s = database.skills[id]
      push_auto_skill(subject, s)
    end
  end

  # ステート適用中に発動するスキルを追加する
  def push_repeat_skill_by_state(subject, state, data)
    return unless flag = state.special_flag(:repeat)
    skill_id, turn, trigger = flag.split(",")
    return unless (skill_id = Integer(skill_id) rescue nil)
    return unless s = database.skills[skill_id]
    turn = Integer(turn) rescue 1
    return unless turn > 0
    trigger = Integer(trigger) rescue 0
    trigger = turn + trigger if trigger < 0

    data.context[:turn_count] ||= 0
    if data.context[:turn_count] % turn == trigger
      push_auto_skill(subject, s)
    end
    data.context[:turn_count] += 1
  end

  def push_auto_skill(subject, skill)
    target = subject.make_target_by_skill(skill)
    action_unit.add_action(subject, target, skill, nil, nil, nil, 0)
  end

  def damage_se(damagetype)
    if @need_to_call_damage_se
      case
      when damagetype.critical
        :play_critical_se
      when damagetype.weakpoint
        :play_weakpoint_se
      when damagetype.blocked
        # かなり軽減した場合
        :play_resisted_se
      when damagetype.resisted
        # 少し軽減した場合
        :play_normal_damage_se
      else
        :play_normal_damage_se
      end
    end
  end

  def action_miss(agent, user, target, data, rate)
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    add_miss_action(target_unit)
  end

  def add_miss_action(target_unit)
    label = self.lang_message.text(:action_miss)
    damage_unit.add(target_unit, label, 20, Itefu::Color.White, Itefu::Color.Black)
  end

  def add_cancel_action(target_unit)
    label = self.lang_message.text(:action_cancel)
    damage_unit.add(target_unit, label, 20, Itefu::Color.White, Itefu::Color.Black)
  end


  def action_hp_damage(agent, value, user, target, data, rate, damagetype)
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    if value >= 0
      # Positive Damage
      damagetype = target_unit.convert_damagetype(damagetype)
      sound = damage_se(damagetype)
      target_unit.play_damage_animation if target.alive?
      damage_unit.add_ex(target_unit, agent, value, rate, sound, damagetype)
      # Absorb into HP
      if target.in_state_with_special_flag?(:absorb_hp)
        r = target.sum_state_special_flag(:absorb_hp)
        if r > 0
          # 最低1保証
          d = Itefu::Utility::Math.max(1, value * r).to_i
          target.add_hp(d)
          damage_unit.add(target_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Red) if d > 0
        end
      end
      # Absorb into MP
      if target.in_state_with_special_flag?(:absorb_mp)
        r = target.sum_state_special_flag(:absorb_mp)
        if r > 0
          # 最低1保証
          d = Itefu::Utility::Math.max(1, value * r).to_i
          target.add_mp(d)
          damage_unit.add(target_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Blue)
        end
      end
      # Drain HP
      if user && user.in_state_with_special_flag?(:drain_hp)
        d = (value * user.sum_state_special_flag(:drain_hp)).to_i
        if d > 0
          user.add_hp(d)
          user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
          damage_unit.add(user_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Red) if d > 0
        end
      end
      # Drain MP
      if user && user.in_state_with_special_flag?(:drain_mp)
        d = (value * user.sum_state_special_flag(:drain_mp)).to_i
        if d > 0
          user.add_mp(d)
          user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
          damage_unit.add(user_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Blue)
        end
      end
      # Gain HP
      if target.dead? && user && user.in_state_with_special_flag?(:gain_hp)
        d = user.sum_state_special_flag(:gain_hp).to_i
        if d > 0
          user.add_hp(d)
          user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
          damage_unit.add(user_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Red) if d > 0
        end
      end
      # Gain MP
      if target.dead? && user && user.in_state_with_special_flag?(:gain_mp)
        d = user.sum_state_special_flag(:gain_mp).to_i
        if d > 0
          user.add_mp(d)
          user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
          damage_unit.add(user_unit, "+#{d.abs}", 20, Itefu::Color.White, Itefu::Color.Blue)
        end
      end
      # Gimmick
      if (gimmick = target.battler.gimmick) &&
          gimmick.trigger == :hp &&
          target.hp + value > gimmick.threshold &&
          target.hp <= gimmick.threshold
        case gimmick.command
        when :state
          target.add_state(gimmick.params[0])
        when :graphic
          target_unit.change_graphic(*gimmick.params)
        end
      end
    else
      # Negative Damage
      damage_unit.add(target_unit, "+#{value.abs}", (20*rate), Itefu::Color.White, Itefu::Color.Red)
    end
  end

  def action_hp_drain(agent, value, user, target, data, rate)
    user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
    if value >= 0
      user_unit.play_damage_animation if target.alive?
      damage_unit.add(user_unit, value, 20, Itefu::Color.White, Itefu::Color.Red)
    else
      damage_unit.add(user_unit, value, 20, Itefu::Color.Red, Itefu::Color.Black)
    end
  end

  def action_mp_damage(agent, value, user, target, data, rate, damagetype)
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    if value >= 0
      damagetype = target_unit.convert_damagetype(damagetype)
      sound = damage_se(damagetype)
      target_unit.play_damage_animation if target.alive?
      damage_unit.add(target_unit, value, (20*rate).to_i, damagetype.critical ? Itefu::Color.Yellow : Itefu::Color.Blue, damagetype.critical ? Itefu::Color.Blue : Itefu::Color.Black, sound, damagetype)
    else
      damage_unit.add(target_unit, "+#{value.abs}", (20*rate).to_i, Itefu::Color.White, Itefu::Color.Blue)
    end
  end

  def action_mp_drain(agent, value, user, target, data, rate)
    user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
    if value >= 0
      user_unit.play_damage_animation if target.alive?
      damage_unit.add(user_unit, value, 20, Itefu::Color.White, Itefu::Color.Blue)
    else
      damage_unit.add(user_unit, value, 20, Itefu::Color.Blue, Itefu::Color.Black)
    end
  end

  def action_add_state(agent, state_id, result, user, target, data, rate)
    if result.nil?
      # miss
      @damage_work[:miss_state] = true unless @damage_work.has_key?(:miss_state)
      return
    end
    @damage_work[:miss_state] = false

    return unless state = database.states[state_id]
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    label = state.label_name
    c = Itefu::Color.Yellow
    o = Itefu::Color.Black
    unless result || label.empty?
      # resisted
      c = Itefu::Color.LightGrey
      if target.resisted_state?(state_id) || target.state_resistance(state_id) >= 100
        # 完全耐性
        label = self.lang_message.text(:state_immuned) % label
      else
        # 抵抗値あり
        label = self.lang_message.text(:state_resisted) % label
      end
      sound = :play_state_resisted_se
      dt = Game::Agency::DamageType.new
      dt.resisted = true
    end
    damage_unit.add(target_unit, label, 20, c, o, sound, dt) unless label.empty?

    return unless result
    # 以降は成功した場合のみの処理

    case state_id
    when Itefu::Rgss3::Definition::State::DEAD
      if target_unit.status.dead?
        # ステートを付与するだけでなく完全に死なせる
        target_unit.status.die
      end
    end

    if Itefu::Rgss3::Definition::State::Restriction.uncontrollable?(state.restriction)
      action_unit.select_actions(target_unit).each do |action|
        action.subject.update_action_by_state_restriction(action, state)
      end
    end
  end

  def action_remove_state(agent, state_id, result, user, target, data, rate)
    state = database.states[state_id]

    # 混乱解除時の処理
    if state && Itefu::Rgss3::Definition::State::Restriction.upset?(state.restriction)
      unless target.uncontrollable?
        # このステートを解除した結果操作不能状態が解消された
        target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
        target_unit.replace_confusing_action(action_unit)
      end
    end

    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)

    case state_id
    when Itefu::Rgss3::Definition::State::DEAD
      # 蘇生時の処理
      target_unit.apply_auto_state(0)
    end
  end

  def action_effect_applied(agent, effects, user, target, rate)
    if @damage_work[:miss_state]
      # ステート付与があり付与に失敗
      if agent && agent.item && agent.item.damage.none?
        # ダメージのないスキルでステート付与に失敗した場合はMISSを出す
        action_miss(agent, user, target, nil, rate)
      end
    end
  end


  def action_state_eased(agent, state, user, target, data, rate)
    # スキル解放と連動して自動発動するスキル
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    push_chain_skill_by_state(target_unit, state)

    if Itefu::Rgss3::Definition::State::Restriction.upset?(state.restriction)
      # 混乱のダメージ解除での処理
      db_states = database.states
      if target.states.one? {|state_id|
        next unless state = db_states[state_id]
        Itefu::Rgss3::Definition::State::Restriction.upset?(state.restriction)
      }
        # このステートを解除したら混乱状態が解消される
        target_unit.replace_confusing_action(action_unit)
      end
    end
  end

  def action_special(agent, id, user, target, data, rate)
    target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
    unless target_unit.escape
      add_miss_action(target_unit)
    end
  end

  def action_common_event(agent, event_id, user, target, data, rate)
    if event = database.common_events[event_id]
      interpreter_unit.start_battle_event(nil, event_id, event.list)
    end
  end

  def action_note(agent, id, value, user, target, item)
    case id
    when :speed_damage
      target_unit = troop_unit.find_enemy_unit(target) || party_unit.find_actor_unit(target)
      action_unit.select_actions(target_unit).each do |action|
        play_action_damage_animation(action)
        action.speed -= value
      end
      action_unit.confirm_action
      action_unit.update_action_list
    when :retarget
      # 敵のターゲットを選択しなおす
      user_unit = troop_unit.find_enemy_unit(user) || party_unit.find_actor_unit(user)
      actions = case value
        when :attract
          # userが狙われていなかったら
          action_unit.find_actions_by {|action|
            ts = action.target.call
            ts.size == 1 &&   # 単体攻撃のみ対象
              user_unit.equal?(ts[0]).!
          }
        when :distract
          # userが狙われていたら
          action_unit.find_actions_by {|action|
            ts = action.target.call
            ts.size == 1 &&   # 単体攻撃のみ対象
              user_unit.equal?(ts[0])
          }
        end
      # ターゲットを再設定する
      actions.each do |action|
        action.target = action.subject.make_target_by_skill(action.item)
      end
    end
  end

  def action_regenerate_hp(value, target_unit, rate = 1)
    if value < 0
      sound = :play_actor_damage_se if @need_to_call_damage_se
      damage_unit.add(target_unit, value.abs, (20*rate), Itefu::Color.Red, Itefu::Color.Black, sound)
    else
      sound = :play_recovery_se if @need_to_call_damage_se
      damage_unit.add(target_unit, "+#{value.abs}", (20*rate), Itefu::Color.White, Itefu::Color.Red, sound)
    end
  end

  def action_regenerate_mp(value, target_unit, rate = 1)
    if value < 0
      sound = :play_actor_damage_se if @need_to_call_damage_se
      damage_unit.add(target_unit, value.abs, (20*rate).to_i, Itefu::Color.Blue, Itefu::Color.Black, sound)
    else
      sound = :play_recovery_se if @need_to_call_damage_se
      damage_unit.add(target_unit, "+#{value}", (20*rate).to_i, Itefu::Color.White, Itefu::Color.Blue, sound)
    end
  end

  def apply_regenerate(target_unit)
    old = @need_to_call_damage_se
    @need_to_call_damage_se = true

    if target_unit.available?
      value = target_unit.take_auto_heal
      action_regenerate_hp(value, target_unit) if value > 0
    end
    if target_unit.available?
      value = target_unit.take_slip_damage
      action_regenerate_hp(value, target_unit) if value < 0
    end

    if target_unit.available?
      value = target_unit.regenerate_mp
      action_regenerate_mp(value, target_unit) if value != 0
    end

    @need_to_call_damage_se = old
  end

end


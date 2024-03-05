=begin
  パーティメンバーのステート(状態)
=end
module SaveData::Game::Actor::State
  def hp; raise Itefu::Exception::NotImplemented; end 

  class StateData
    attr_accessor :turn_count, :walk_count
    attr_reader :context

    def ==(rhs)
      self.turn_count == rhs.turn_count &&
      self.walk_count == rhs.walk_count &&
      self.context == rhs.context
    end

    def context
      @context ||= {}
    end
  end

  def states
    @states.keys
  end

  def state_data
    @states
  end

  # ステートを全解除
  def clear_states
    @states = {}
    clear_state_cache
  end

  # 特定のステートにあるか
  def in_state_of?(state_id)
    @states.has_key?(state_id)
  end

  # 特殊フラグが指定されているステートにあるか
  def in_state_with_special_flag?(key)
    db = Application.database.states
    @states.each_key.any? {|state_id| db[state_id].special_flag(key) }
  end

  # @return [Float] 特殊フラグで指定されている数値の合計
  def sum_state_special_flag(key)
    db = Application.database.states
    @states.each_key.inject(0) {|memo, state_id|
      next memo unless value = db[state_id].special_flag(key)
      next memo unless value = Rational(value) rescue nil
      memo + value
    }.to_f
  end

  # @return [Float] 特殊フラグで指定されている数値を掛け合わせる
  def fold_state_special_flag(key)
    db = Application.database.states
    @states.each_key.inject(1.0) {|memo, state_id|
      next memo unless value = db[state_id].special_flag(key)
      next memo unless value = Float(value) rescue nil
      memo * value
    }
  end

  # 排他ステートがあればそれを取得
  def exclusive_state(exclude_key)
    db = Application.database.states
    id = states.find {|state_id|
      db[state_id].exclude_key == exclude_key
    }
    id && db[id]
  end

  # 行動制約
  def state_restriction
    db = Application.database.states
    ret = Itefu::Rgss3::Definition::State::Restriction::NONE
    @states.each_key.find do |state_id|
      # 一番きつい制約を探す
      ret = Itefu::Utility::Math.max(ret, db[state_id].restriction)
      Itefu::Rgss3::Definition::State::Restriction.unmovable?(ret)
    end
    ret
  end

  # 行動不能か
  def unmovable?
    db = Application.database.states
    @states.each_key.any? {|state_id|
      Itefu::Rgss3::Definition::State::Restriction.unmovable?(db[state_id].restriction)
    }
  end

  # 操作不能か
  def uncontrollable?
    db = Application.database.states
    @states.each_key.any? {|state_id|
      Itefu::Rgss3::Definition::State::Restriction.uncontrollable?(db[state_id].restriction)
    }
  end

  # 耐性のあるステートか
  def resisted_state?(state_id)
    false
  end

  # 最大優先度のステート
  def state_top_priority(basic_only = true)
    db = Application.database.states
    if basic_only
      id = @states.each_key.max_by {|state_id|
        db[state_id].basic_state? ? db[state_id].priority : -1
      }
      db[id].basic_state? && db[id]
    else
      id = @states.each_key.max_by {|state_id|
        db[state_id].priority
      }
      db[id]
    end
  end

  # ステート付与
  # @return 付与したステート情報
  def add_state(state_id, force = false)
    return unless state = Application.database.states[state_id]
    return if force.! && resisted_state?(state_id)

    # exclusiveなステート同士の処理
    if state.exclusive? && (exstate = exclusive_state(state.exclude_key)) && exstate.id != state_id
      if exstate.priority < state.priority
        # すでに優先度の高いステートがあるので無視する
        return
      else
        # 優先度の低いステートを解除する
        remove_state(exstate.id)
      end
    end

    # 行動制約による解除
    if Itefu::Rgss3::Definition::State::Restriction.uncontrollable?(state.restriction)
      remove_states_due_to_restriction
    end

    # 自動解除の設定
    newstate = @states[state_id] = StateData.new
    if state.auto_removal_timing != Itefu::Rgss3::Definition::State::AutoRemovalTiming::NONE
      if state.min_turns == 0 && state.max_turns == 0
        newstate.turn_count = Float::INFINITY
      else
        newstate.turn_count = Itefu::Utility::Math.rand_in(state.min_turns, state.max_turns)
      end
    end
    if state.remove_by_walking
      newstate.walk_count = state.steps_to_remove
    end

    clear_state_cache
    newstate
  end

  # 特定のステートを解除
  def remove_state(state_id)
    if @states.delete(state_id)
      clear_state_cache
      true
    end
  end

  # 戦闘終了時に解除されるステートを解除
  def remove_states_due_to_batttle_termination
    db = Application.database.states
    if block_given?
      if @states.reject! {|key, value|
        db[key].remove_at_battle_end && yield(db[key])
      }
        clear_state_cache
        true
      end
    else
      if @states.reject! {|key, value|
        db[key].remove_at_battle_end
      }
        clear_state_cache
        true
      end
    end
  end

  # 行動制約によって解除されるステートを解除
  def remove_states_due_to_restriction
    db = Application.database.states
    if block_given?
      if @states.reject! {|key, value|
        db[key].remove_by_restriction && yield(db[key])
      }
        clear_state_cache
        true
      end
    else
      if @states.reject! {|key, value|
        db[key].remove_by_restriction
      }
        clear_state_cache
        true
      end
    end
  end

  # ダメージによって解除されるステートを解除
  def remove_state_due_to_damage
    db = Application.database.states
    if block_given?
      if @states.reject! {|key, value|
        state = db[key]
        state.remove_by_damage && (rand(100) < state.chance_by_damage) && yield(state)
      }
        clear_state_cache
        true
      end
    else
      if @states.reject! {|key, value|
        state = db[key]
        state.remove_by_damage && (rand(100) < state.chance_by_damage)
      }
        clear_state_cache
        true
      end
    end
  end

  # 連続攻撃など一連の行動を受け終わったあとに一度だけ判定するステートを解除
  def remove_state_due_to_total_damage
    db = Application.database.states
    if block_given?
      if @states.reject! {|key, value|
        state = db[key]
        state.patient? && (hp <= 1) && yield(state)
      }
        clear_state_cache
        true
      end
    else
      if @states.reject! {|key, value|
        state = db[key]
        state.patient? && (hp <= 1)
      }
        clear_state_cache
        true
      end
    end
  end

  # 自動解除の条件をみたしたステートを解除
  def remove_states_due_to_eased_out
    if block_given?
      db = Application.database.states
      if @states.reject! {|key, value|
        ((value.turn_count && value.turn_count <= 0) ||
         (value.walk_count && value.walk_count <= 0)) && yield(db[key])
      }
        clear_state_cache
        true
      end
    else
      if @states.reject! {|key, value|
        (value.turn_count && value.turn_count <= 0) ||
        (value.walk_count && value.walk_count <= 0)
      }
        clear_state_cache
        true
      end
    end
  end

  # タイミングで解除されるステートを緩和
  # @param [Itefu::Rgss3::Definition::Sate::AutoRemovalTiming] timing どの解除条件に対して処理するか
  # @note auto_removeを指定しない場合、無条件に解除カウンタを進める
  def ease_states_due_to_timing(timing = nil)
    db = Application.database.states
    if timing
      @states.each do |key, value|
        if db[key].auto_removal_timing == timing
          value.turn_count -= 1
          yield(db[key], value) if value.turn_count > 0 && block_given?
        end
      end
    else
      @states.each do |key, value|
        if value.turn_count
          value.turn_count -= 1
          yield(db[key], value) if value.turn_count > 0 && block_given?
        end
      end
    end
  end

  # 歩行で解除されるステートを緩和
  def ease_states_due_to_walk
    db = Application.database.states
    @states.each do |key, value|
      value.walk_count -= 1 if value.walk_count
    end
  end

  # キャッシュのクリア
  def clear_state_cache
    @cache_param_scale.clear if @cache_param_scale
  end

  # ステートで指定するパラメータ最終値への乗算値
  def param_scale(id)
    @cache_param_scale ||= {}
    @cache_param_scale[id] ||= fold_state_special_flag(id)
  end

end


=begin
  Actor/Enemy共通処理
=end
module Battle::Unit::Battler
  def sitaigeri?; false; end
  def has_inventory?; false; end
  def effect_scale; 1.0; end

  DamageData = Struct.new(:value, :size, :color, :out_color, :sound, :type, :data)
  module DamageType
    NORMAL = nil
    WEAKPOINT = :weakpoint
    RESISTED = :resisted
  end

  def setup_damage_animation
    @anime_damage = 
    @anime_damage_normal = Itefu::Animation::Sequence.new.tap {|a|
      a.add_animation(@damage_control.animation_data(:in))
      a.add_animation(Itefu::Animation::Wait.new(10))
      a.add_animation(Itefu::Animation::Wait.new(0))
      a.add_animation(Itefu::Animation::Wait.new(80))
      a.add_animation(@damage_control.animation_data(:out))
    }
    @anime_damage_solid = Itefu::Animation::Sequence.new.tap {|a|
      a.add_animation(Itefu::Animation::Wait.new(0))
      a.add_animation(@damage_control.animation_data(:in_solid))
      a.add_animation(Itefu::Animation::Wait.new(0))
      a.add_animation(Itefu::Animation::Wait.new(80))
      a.add_animation(@damage_control.animation_data(:out))
    }
    @anime_damage_resist = Itefu::Animation::Sequence.new.tap {|a|
      a.add_animation(@damage_control.animation_data(:in_resist))
      a.add_animation(Itefu::Animation::Wait.new(10))
      a.add_animation(Itefu::Animation::Wait.new(0))
      a.add_animation(Itefu::Animation::Wait.new(80))
      a.add_animation(@damage_control.animation_data(:out))
    }
    @anime_damage_weak = Itefu::Animation::Sequence.new.tap {|a|
      a.add_animation(@damage_control.animation_data(:in_weak))
      a.add_animation(Itefu::Animation::Wait.new(10))
      a.add_animation(Itefu::Animation::Wait.new(0))
      a.add_animation(Itefu::Animation::Wait.new(80))
      a.add_animation(@damage_control.animation_data(:out))
    }
  end

  def show_damage(value, size, color, out_color, data, sound = nil, type = DamageType::NORMAL)
    # ステート付与をもつ連続攻撃用に数字の後に文字列をまとめる
    case (Integer(value) rescue value)
    when Numeric
      # 数値を先に出す
      index = @damages.find_index {|d|
        Integer(d.value) && false rescue true
      } || @damages.size
      @damages.insert(index, DamageData.new(value, size, color, out_color, sound, type, data))
    when String
      # 同時に同じステートなどが与えられた場合はまとめる
      unless @damages.find {|d| d.value == value }
        @damages << DamageData.new(value, size, color, out_color, sound, type, data)
      end
    else
      @damages << DamageData.new(value, size, color, out_color, sound, type, data)
    end
  end

  # to be over-ridden
  def apply_auto_state(turn_count); end
  def remove_auto_state(target); end

  # to be over-ridden
  def convert_damagetype(damagetype)
    damagetype
  end

  # to be over-ridden
  def replace_confusing_action(action_unit); end

  def update_action_by_state_restriction(action, state)
    nullify_action_by_state_restriction(action, state)
  end

  def nullify_action_by_state_restriction(action, state)
    if state.message3.empty?
      action.label = state.special_flag(:label) || state.name
    else
      action.label = state.message3
    end
    action.item = nil
  end

private

  def process_damage
    return if @anime_damage.playing? && @anime_damage.playing_index == 0
    return if @damages.empty?
    damage = @damages.first

    if @anime_damage.playing? && @anime_damage.playing_index <= 2
      # 表示だけを差し替える
      return unless @anime_damage.playing_index == 1 && @damage_piled.! || @anime_damage.playing_index == 2
      damage = @damages.first
      return unless damage &&
          damage.value.is_a?(Numeric) &&
          @viewmodel.value.value.is_a?(Numeric)
      @damages.shift
      take_damage(damage.value)

      @viewmodel.value = @viewmodel.value.value + damage.value
      @viewmodel.size  = @viewmodel.size.value + 2 # @magic 少しずつサイズを大きくする
      @viewmodel.color     = damage.color
      @viewmodel.out_color = damage.out_color
      @viewmodel.damage_infos = make_damage_info(damage.data)
      manager.play_raw_animation(self, @anime_damage_solid, 1)
      @anime_damage = @anime_damage_solid
      @damage_piled = true
    else
      # 普通にダメージを出す
      return unless damage = @damages.shift
      take_damage(damage.value)

      @viewmodel.value     = damage.value
      @viewmodel.size      = damage.size
      @viewmodel.color     = damage.color
      @viewmodel.out_color = damage.out_color
      @viewmodel.damage_infos = make_damage_info(damage.data)
      case damage.type
      when DamageType::WEAKPOINT
        manager.play_raw_animation(self, @anime_damage_weak)
        @anime_damage = @anime_damage_weak
      when DamageType::RESISTED
        manager.play_raw_animation(self, @anime_damage_resist)
        @anime_damage = @anime_damage_resist
      else
        manager.play_raw_animation(self, @anime_damage_normal)
        @anime_damage = @anime_damage_normal
      end
      @damage_piled = false
    end

    if damage.sound && manager.sound
      manager.sound.send(damage.sound)
    end
  end

  def make_damage_info(data)
    ret = []
    return ret unless data
    return ret unless lang = manager.lang_message

    # 会心
    if data.critical
      ret << lang.text(:damage_critical)
    end
    # 言咎め
    if data.cursed
      ret << lang.text(:damage_cursed)
    end
    # 弱点
    if data.weakpoint
      if name = Application.database.system.rawdata.elements[data.weakpoint]

        name = name[0]
        ret << (lang.text(:damage_weakpoint) % name)
      end
    end
    # 耐性
    if data.resisted
      if name = Application.database.system.rawdata.elements[data.resisted]
        name = name[0]
        ret << (lang.text(:damage_resisted) % name)
      end
    end

    ret
  end

  # to be over-ridden
  def take_damage(damage); end


public

  def make_target_by_skill(skill)
    case skill.scope
    when Itefu::Rgss3::Definition::Skill::Scope::OPPONENT
      # 敵から選択
      # 選択時にランダムに選ぶ
      if sitaigeri?
        opponent_unit.make_target_random(1, true).call.first.make_target
      else
        opponent_unit.make_target_random(1).call.first.make_target
      end
    when Itefu::Rgss3::Definition::Skill::Scope::FRIEND
      # 味方から選択
      # 選択時にランダムに選ぶ
      friend_unit.make_target_random(1).call.first.make_target
    when Itefu::Rgss3::Definition::Skill::Scope::DEAD_FRIEND
      # 味方から選択
      # 選択時にランダムに選ぶ
      friend_unit.make_target_random_dead(1).call.first.make_target
    when Itefu::Rgss3::Definition::Skill::Scope::MYSELF
      # 使用者自身
      self.make_target
    when Itefu::Rgss3::Definition::Skill::Scope::ALL_FRIENDS
      # 全ての味方
      friend_unit.make_target_all
    when Itefu::Rgss3::Definition::Skill::Scope::ALL_DEAD_FRIENDS
      # 全ての死んだ味方
      friend_unit.make_target_all_dead
    when Itefu::Rgss3::Definition::Skill::Scope::ALL_OPPONENTS
      # 全ての敵
      if sitaigeri?
        opponent_unit.make_target_all(true)
      else
        opponent_unit.make_target_all
      end
    else
      # ランダムまたは対象なし
      # 実行時にランダムに選ぶ
      count = Itefu::Rgss3::Definition::Skill::Scope.random_count(skill.scope)
      if 0 < count
        if sitaigeri?
          opponent_unit.make_target_random(count, true)
        else
          opponent_unit.make_target_random(count)
        end
      end
    end
  end

end


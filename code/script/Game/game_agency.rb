=begin
  ゲーム内の世界のルール
=end
module Game::Agency

  DamageType = Struct.new(:weakpoint, :resisted, :critical, :blocked)

  # 行動値に応じて行動順序を決める値を計算する
  # @note 乱数を含むので、行動選択ごとでなく、ターンごとに呼ぶなどする
  def self.action_speed(user)
    base = (user.footwork * user.attack_speed_rate).to_i
    # 基礎値
    base +
      # ぶれ幅
      rand(Application.config.speed_rand.call(base)) +
      # 同値の順序決め
      rand
  end


  # @return [Boolean] 使用者のスキルを対象者が見切ることができるか
  def self.check_revealing_action(user, target, rand = Random)
    # v = 30 + user.prove_skill_x - target.prove_skill_x
    # rand.rand(100) < v
    # 何度もくらってなかなか判明しないのはストレスフルなので一旦常に見切れるようにする
    true
  end

  # @return [Float] 耐性を有効度に変換する
  def self.resistance_to_conductance(reg)
    Itefu::Utility::Math.max(0, 100 - reg) / 100.0
  end

  def self.important_item?(item)
    case item
    when RPG::Item
      item.key_item?
    else
      item.special_flag(:important).nil?.!
    end
  end

  # @return [Integer] 命中率 (百分率)
  def self.hit_rate(user, target, item)
    # 対象が行動不能なら必中
    return 100 if target.unmovable?

    diff = item.special_flag(:hit)
    diff = diff && Integer(diff) || 0
    case item.hit_type
    when Itefu::Rgss3::Definition::Skill::HitType::PHYSICAL
      hit = Application.config.phit_base + user.accuracy + diff
      eva = target.evasion
      hit * user.hit_rate - eva * target.physic_evasion_rate
    when Itefu::Rgss3::Definition::Skill::HitType::MAGICAL
      Application.config.mhit_base + diff - target.magic_evasion_x
    else
      100
    end
  end

  # @return [Array<Fixnum>] スキルやアイテムの属性をIDの配列で返す
  def self.item_elements(user, item)
    return [] if item.damage.type == 0
    eid = item.damage.element_id
    if eid < 0
      # 通常攻撃
      user.attack_element_ids.keys
    elsif eid > 0
      # 属性指定
      [ eid ]
    else
      []
    end
  end


  # スキルやアイテムなどの効果を適用
  class Damage
    include Itefu::Utility::Callback
    attr_accessor :unif_rand, :norm_rand
    attr_reader :item
    attr_reader :data

    # ダメージ表示に使う詳細情報
    # @todo DamageType と役割が被っている。開発終盤の仕様変更の影響を小さくするための実装で、リファクタリングされるべき
    AdditionalData = Struct.new(:hit, :critical, :weakpoint, :resisted, :cursed) do
      def clear
        self.each_pair do |key|
          self[key] = nil
        end
      end
    end

    def [](id)
      Application::Accessor::Flags.variable(id)
    end

    def unif_rand
      @unif_rand || Random
    end

    def norm_rand
      @norm_rand || Itefu::Utility::Math::NormalRandom
    end

    def apply_item(user, target, item, rate = 1)
      @item = item
      @damaged = false
      item.repeats.times do
        apply_item_impl(user, target, item, rate)
      end
      if @damaged
        target.remove_state_due_to_total_damage {|state|
          execute_callback(:state_eased, state, user, target, item.damage, rate)
          true
        }
      end
    end

    def apply_item_impl(user, target, item, rate)
      @data = AdditionalData.new
      critical_hit = @data[:critical] = item.damage.critical && check_critical(user, target)
      hit = @data[:hit] = check_hit(user, target, item)
      if hit
        if critical_hit
          rate *= Application.config.critical_rate
        end
      else
        unless critical_hit
          execute_callback(:miss, user, target, item, rate)
          return
        end
      end

      @hp_damage = @mp_damage = 0
      # ダメージ倍率を自動設定する
      typer = 1
      case item
      when RPG::Skill
        if item.stype_id == 2 # @magic: 術式
          typer = target.magic_damage_rate
        else
          typer = target.physic_damage_rate
        end
      else
        typer = target.physic_damage_rate
      end unless item.damage.recover?

      # ダメージ計算
      damagetype = apply_damage(user, target, item.damage, typer, rate)
      damagetype.critical = critical_hit
      if damagetype.weakpoint
        dmgr = rate * Application.config.weak_rate
      else
        dmgr = rate
      end
      # 独自効果
      apply_note(user, target, item, rate)
      # 特殊効果
      item.effects.each do |effect|
        apply_effect(user, target, effect, rate)
      end
      # 特殊効果適用終わり
      execute_callback(:effect_applied, item.effects, user, target, rate)
      # ダメージ（一括で与える場合）
      if item.damage.to_hp? || @hp_damage != 0
        execute_callback(:hp_damage, @hp_damage, user, target, item, dmgr, damagetype)
      end
      if item.damage.to_mp? || @mp_damage != 0
        execute_callback(:mp_damage, @mp_damage, user, target, item, dmgr, damagetype)
      end
      @hp_damage = @mp_damage = nil
    end

    # @return [Boolean] クリティカルが発動するか
    def check_critical(user, target)
      if user.luck > target.luck
        v = (user.luck - target.luck) ** 2
      else
        v = 1
      end
      unif_rand.rand(10000) < v
    end

    # @return [Boolean] スキルがヒットするか
    def check_hit(user, target, item)
      return false unless unif_rand.rand(100) < item.success_rate

      unif_rand.rand(100) < Game::Agency.hit_rate(user, target, item)
    end

    def apply_damage(user, target, damage, typer, rate = 1)
      return DamageType.new if damage.none?
      a = user
      b = target
      v = self

      # 属性補正
      weakpoint = false
      resisted = false
      if damage.element_id < 0
        element_ids = user.attack_element_ids
        # 弱点を考慮して一番効く属性を選ぶ
        eid = element_ids.min_by {|eid, elv|
          erg = target.element_resistance(eid)
          erg - elv
        }.first
      else
        eid = damage.element_id
      end
      elv = user.attack_element_level(eid)
      erg = target.element_resistance(eid)
      weakpoint = eid if erg < 0
      resisted = eid if erg > 0
      erg = erg - elv
      elemr = Game::Agency.resistance_to_conductance(erg)
      elemr_gain = Game::Agency.resistance_to_conductance(-elv)
      @data[:cursed] = target.in_state_of?(7) # @magic: 言咎め
      @data[:weakpoint] = weakpoint
      @data[:resisted] = resisted
      weakpoint = true if weakpoint # converting into Boolean
      resisted = true if resisted # converting into Boolean
      damagetype = DamageType.new(weakpoint, resisted)

      # ダメージの耐性判定基準値を算出
      r = rate * elemr_gain
      dmg_base1, _ = (instance_eval(damage.formula) || 0 rescue 0)
      # 平均ダメージを算出
      r = rate * elemr
      dmg_avg, dmg_low = (instance_eval(damage.formula) || 0 rescue 0)
      dmg_base2 = dmg_avg
      dmg_low ||= 0
      # 保証値を下回る計算結果が入る可能性があるので
      dmg_avg = Itefu::Utility::Math.max(dmg_low, dmg_avg)

      # エディタで設定できるvarianceをSDとして使うことにしている
      sigma = dmg_avg * damage.variance / 100.0
      begin
        offset = norm_rand.rand(0, sigma)
      # σ2区間に収まる範囲で算出する
      end until (-2 * sigma <= offset) && (offset <= 2 * sigma)
      # σ2区間を超えるダメージはそこでカットする
      # offset = Itefu::Utility::Math.clamp(-sigma*2, sigma*2, offset)
      dmg = (dmg_avg + offset).round

      # 属性の軽減
      if damage.element_id < 0
        element_ids = user.attack_element_ids
        elm_diff = element_ids.inject(0) do |memo, (eid, elv)|
          memo + target.element_deduction(eid)
        end
      else
        elm_diff = target.element_deduction(damage.element_id)
      end
      dmg -= elm_diff

      # 軽減率をチェックする
      dmg_base2 -= elm_diff
      if dmg_base2 / dmg_base1 <= Application.config.block_threshold
        # 十分に軽減した
        # @note プレイヤー側は多くの装備にわずかに耐性を持っているので、それなりに軽減したときだけ、強い耐性演出をするようにする
        damagetype.blocked = true
      end

      # キャラ個別の軽減
      unless damage.recover?
        dmgcut = (Integer(target.battler.special_flag(:damage_cut)) rescue 0)
        dmg -= dmgcut
      end

      # 物理／魔法軽減
      dmg = (dmg * typer).to_i

      # あれこれ計算したあと再生保証値を下回っていないか
      dmg = Itefu::Utility::Math.max(dmg_low, dmg)
      # 防御
      defensive = target.defence?
      dmg /= 2 if defensive && damage.recover?.!
      # 防御時でも保証値1のときは1を保証する
      dmg = Itefu::Utility::Math.max(dmg_low, dmg) if dmg_low == 1
      # 最終結果
      dmg = dmg * damage.sign

      case
      when damage.to_hp?
        if dmg >= target.hp
          case
          when defensive && target.endurance?(true) && target.hp > 1
            # 防御複数重ねのふんばり
            target.add_state(172) # @magic: 不死身用隠しステート
          when target.in_state_of?(180) # @magic: 身代わり待機用の隠しステート
            # 身代わりの処理
            target.add_state(179)       # @magic: 身代わり用隠しステート
          end unless target.immortal?
        end
        target.add_hp(-dmg)
        if dmg >= 0
          target.remove_state_due_to_damage {|state|
            execute_callback(:state_eased, state, user, target, damage, rate)
            true
          }
          @damaged = true
        end
        user.add_hp(dmg) if damage.drain?
        if @hp_damage
          @hp_damage += dmg
        else
          execute_callback(:hp_damage, dmg, user, target, damage, rate, damagetype)
        end
        execute_callback(:hp_drain, dmg, user, target, damage, rate) if damage.drain?
      when damage.to_mp?
        target.add_mp(-dmg)
        user.add_mp(dmg) if damage.drain?
        if @mp_damage
          @mp_damage += dmg
        else
          execute_callback(:mp_damage, dmg, user, target, damage, rate, :damagetype)
        end
        execute_callback(:mp_drain, dmg, user, target, damage, rate) if damage.drain?
      end

      damagetype
    end

    def apply_note(user, target, item, rate)
      # 戦闘時の行動順序を変動させる
      if value = item.special_flag(:speed_damage)
        execute_callback(:note, :speed_damage, value, user, target, item)
      end
      # ターゲットをリセットする
      if value = item.special_flag(:retarget)
        execute_callback(:note, :retarget, value.intern, user, target, item)
      end
      # 経験値を増減する
      if value = item.special_flag(:exp)
        old_level = target.level
        old_skills = target.skills_raw.clone
        old_job_name = target.job_name
        target.add_exp(value)
        if target.level > old_level
          target.recover_by_leveling_up(old_level)
          execute_callback(:note, :exp_levelup, [value, old_level, old_skills, old_job_name], user, target, item)
        else
          execute_callback(:note, :exp, value, user, target, item)
        end
      end
    end

    def apply_effect(user, target, effect, rate = 1)
      case effect.code
      when Itefu::Rgss3::Definition::Skill::Effect::RECOVER_HP
        # HP回復
        value = (target.mhp * effect.value1 + effect.value2) * rate
        value = value.to_i
        # @todo 負の回復の場合があるので本当はここにもふんばりの処理が必要
        target.add_hp(value)
        if value < 0
          target.remove_state_due_to_damage {|state|
            execute_callback(:state_eased, state, user, target, effect, rate)
            true
          }
          @damaged = true
        end
        if @hp_damage
          @hp_damage -= value
        else
          execute_callback(:hp_damage, -value, user, target, effect, rate, nil)
        end
      when Itefu::Rgss3::Definition::Skill::Effect::RECOVER_MP
        # MP回復
        value = (target.mhp * effect.value1 + effect.value2) * rate
        value = value.to_i
        target.add_mp(value)
        if @mp_damage
          @mp_damage -= value
        else
          execute_callback(:mp_damage, -value, user, target, damage, rate, nil)
        end
      when Itefu::Rgss3::Definition::Skill::Effect::GAIN_TP
        raise Itefu::Exception::NotSupported
      when Itefu::Rgss3::Definition::Skill::Effect::ADD_STATE
        # ステート付与
        chance = effect.value1 * rate # 100% = 1.0
        if effect.data_id == 0
          # 通常攻撃
          user.attack_state_ids.each do |state_id, v|
            ret = apply_state(target, effect, feature.data_id, chance * v / 100)
            execute_callback(:add_state, feature.data_id, ret, user, target, effect, rate)
          end
        else
          # 指定されたステート
          ret = apply_state(target, effect, effect.data_id, chance)
          execute_callback(:add_state, effect.data_id, ret, user, target, effect, rate)
        end
      when Itefu::Rgss3::Definition::Skill::Effect::REMOVE_STATE
        # ステート解除
        succeeded = unif_rand.rand < effect.value1 * rate
        target.remove_state(effect.data_id) if succeeded
        execute_callback(:remove_state, effect.data_id, succeeded, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::ADD_BUFF
        # バフ付与
        target.add_buff(effect.data_id, effect.value1)
        execute_callback(:add_buff, effect.data_id, effect.value1, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::REMOVE_BUFF
        # バフ解除
        target.remove_buff(effect.data_id)
        execute_callback(:remove_buff, effect.data_id, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::ADD_DEBUFF
        # デバフ付与
        succeeded =  unif_rand.rand < rate * target.debuff_conductance(effect.data_id)
        target.add_debuff(effect.data_id, effect.value1) if succeeded
        execute_callback(:add_debuff, effect.data_id, effect.value1, succeeded, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::REMOVE_DEBUFF
        # デバフ解除
        target.remove_debuff(effect.data_id)
        execute_callback(:remove_debuff, effect.data_id, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::SPECIAL
        execute_callback(:special, effect.data_id, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::GROW
        target.add_param(effect.data_id, effect.value1.to_i)
        execute_callback(:grow, effect.data_id, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::LEARN_SKILL
        target.learn_skill(effect.data_id)
        execute_callback(:learn_skill, effect.data_id, user, target, effect, rate)
      when Itefu::Rgss3::Definition::Skill::Effect::COMMON_EVENT
        execute_callback(:common_event, effect.data_id, user, target, effect, rate)
      end
    end

    def apply_state(target, effect, state_id, chance)
      unless unif_rand.rand < chance
        # スキルの失敗
        return nil
      end
      if (database = Application.database) && (db_states = database.states) && (state = db_states[state_id])
        # state の category の仕様を廃止する
        # resist_id = Integer(state.special_flag(:category)) rescue nil
        resist_id = state_id
      end
      if target.resisted_state?(resist_id)
        # 無効化で無効
        return false
      end
      unless unif_rand.rand < target.state_conductance(resist_id)
        # 耐性で無効
        return false
      end
      # 成功
      target.add_state(state_id)
      true
    end

    module Calc
      def physical_damage(user, target, rate = 1)
        ITEFU_DEBUG_OUTPUT_WARNING "pdmg is under construction"
        return 0 if user.attack == 0
        if user.attack < target.defence
          # ATK*(1/(1 + EXP(-(ATK*2-DEF)/DEF * gain:5)))
          rdmg = Itefu::Utility::Math.sigmoid((user.attack*2.0 - target.defence) / target.defence * 5)
        else
          rdmg = 1
        end
        user.attack * rdmg * rate
      end
      alias :physic_damage :physical_damage
      alias :pdmg :physical_damage

      def enemy_physical_damage(user, target, rate = 1)
        ITEFU_DEBUG_OUTPUT_WARNING "epdmg is under construction"
        if user.attack < target.defence / 2
          0
        else
          Itefu::Utility::Math.max(1, user.attack * rate * target.physic_damage_rate - target.defence)
        end
      end
      alias :epdmg :enemy_physical_damage

      def magical_damage(user, target, rate = 1)
        ITEFU_DEBUG_OUTPUT_WARNING "mdmg is under construction"
        user.magic * rate
      end
      alias :magic_damage :magical_damage
      alias :mdmg :magical_damage
      alias :enemy_magical_damage :magical_damage
      alias :emdmg :magical_damage
    end
    include Calc
  end

  # 敵を倒した結果の取得
  class Booty
    attr_reader :amount_of_money
    attr_reader :amount_of_exp
    attr_reader :items
    attr_accessor :database

    def initialize
      @amount_of_money = 0
      @amount_of_exp = 0
      @items = []
    end

    # 敵から戦利品を取得する
    def loot(enemy_data)
      @amount_of_money += enemy_data.gold
      @amount_of_exp += enemy_data.exp
    end

    def loot_items(enemy_data, item_rate = 1, rand = Random)
      db = @database || Application.database
      items = db.items
      weapons = db.weapons
      armors = db.armors

      enemy_data.drop_items.each do |drop_item|
        next unless rand.rand(drop_item.denominator) < item_rate
        case drop_item.kind
        when 1
          add_item items[drop_item.data_id]
        when 2
          add_item weapons[drop_item.data_id]
        when 3
          add_item armors[drop_item.data_id]
        end
      end
    end

    def add_item(item)
      v = item.special_flag(:amount)
      if v.nil? || v > Application::Accessor::GameData.number_of_item(item) + @items.count(item)
        @items << item
      end
    end
  end

end


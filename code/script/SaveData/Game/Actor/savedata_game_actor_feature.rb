=begin 
=end
module SaveData::Game::Actor::Feature
  Feature = Itefu::Rgss3::Definition::Feature

  def features_base(obj = []); raise Itefu::Exception::NotImplemented; end
  def param_base(id); raise Itefu::Exception::NotImplemented; end

  def initialize(*args)
    @features_cache = {}
    super
    # clear_add_params
  end

  # 特徴を再取得する
  def clear_features_cache
    @features_cache.clear
  end

  # --------------------------------------------------
  # ステータス値

  def max_hp; param(Itefu::Rgss3::Definition::Status::Param::MAX_HP); end
  alias :mhp :max_hp

  def max_mp; param(Itefu::Rgss3::Definition::Status::Param::MAX_MP); end
  alias :mmp :max_mp

  # Basic Parameters
  def attack; param(Itefu::Rgss3::Definition::Status::Param::ATTACK); end
  alias :atk :attack
  def defence; param(Itefu::Rgss3::Definition::Status::Param::DEFENCE); end
  alias :def :defence
  def footwork; param(Itefu::Rgss3::Definition::Status::Param::AGILITY); end
  alias :act :footwork
  def accuracy; param(Itefu::Rgss3::Definition::Status::Param::MAGIC_DEFENCE); end
  alias :hit :accuracy
  def evasion; param(Itefu::Rgss3::Definition::Status::Param::LUCK); end
  alias :eva :evasion
  def magic; param(Itefu::Rgss3::Definition::Status::Param::MAGIC_ATTACK); end
  alias :mag :magic

  def attack_base; param_base(Itefu::Rgss3::Definition::Status::Param::ATTACK); end
  def defence_base; param_base(Itefu::Rgss3::Definition::Status::Param::DEFENCE); end
  def footwork_base; param_base(Itefu::Rgss3::Definition::Status::Param::AGILITY); end
  def accuracy_base; param_base(Itefu::Rgss3::Definition::Status::Param::MAGIC_DEFENCE); end
  def evasion_base; param_base(Itefu::Rgss3::Definition::Status::Param::LUCK); end
  def magic_base; param_base(Itefu::Rgss3::Definition::Status::Param::MAGIC_ATTACK); end

  def attack_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::ATTACK); end
  def defence_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::DEFENCE); end
  def footwork_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::AGILITY); end
  def accuracy_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::MAGIC_DEFENCE); end
  def evasion_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::LUCK); end
  def magic_bonus; param_bonus(Itefu::Rgss3::Definition::Status::Param::MAGIC_ATTACK); end

  def luck; xparam(Itefu::Rgss3::Definition::Feature::XParam::CRITICAL_RATE); end
  alias :luk :luck

  # xparams(追加能力値)
  def hit_x; xparam(Feature::XParam::HIT_RATE); end
  def hit_rate; xsparam_x_rate(hit_x); end
  def physic_evasion_x; xparam(Feature::XParam::EVASION_RATE); end
  def physic_evasion_rate; xsparam_x_rate(physic_evasion_x); end
  def magic_evasion_x; xparam(Feature::XParam::MAGIC_EVASION_RATE); end
  def magic_evasion_rate; xsparam_x_rate(magic_evasion_x); end

  # HPR合算値
  def hpr
    (xparam(Feature::XParam::HP_REGENERATION_RATE) +
      mhp * xparam_rate(Feature::XParam::HP_REGENERATION_RATE)
    ).to_i
  end

  # HPR回復分
  def hpr_positive
    return 0 if regeneration_disabled?

    xparam(Feature::XParam::HP_REGENERATION_RATE) {|f|
      f.value > 0 && f.value
    } +
      (mhp * xparam_rate(Feature::XParam::HP_REGENERATION_RATE) {|f|
        f.value > 0 && f.value
      }).ceil
  end

  # HPRダメージ分
  def hpr_negative
    v1 = xparam(Feature::XParam::HP_REGENERATION_RATE) {|f|
      f.value < 0 && f.value
    }
    v2 = mhp * xparam_rate(Feature::XParam::HP_REGENERATION_RATE) {|f|
      f.value < 0 && f.value
    }
    # ドットダメージは切り捨てにするが小数点以下の場合のみ-1に切り上げる
    v1 + ((v2 > -1) ? v2.floor : v2.ceil)
  end

  # MPR合算値
  def mpr
    xparam(Feature::XParam::MP_REGENERATION_RATE) +
      (mmp * xparam_rate(Feature::XParam::MP_REGENERATION_RATE)).ceil
  end

  # sparams(特殊能力値)
  def hate; Itefu::Utility::Math.max(0, 100 + sparam(Feature::SParam::HATE_RATE)); end
  # def hate_rate; xsparam_x_rate(hate_x); end
  def physic_damage_x; sparam(Feature::SParam::PHYSIC_DAMAGE_RATE); end
  def physic_damage_rate; xsparam_x_rate(physic_damage_x); end
  def magic_damage_x; sparam(Feature::SParam::MAGIC_DAMAGE_RATE); end
  def magic_damage_rate; xsparam_x_rate(magic_damage_x); end
  def exp_earning_x; sparam(Feature::SParam::EXP_EARNING_RATE); end
  def exp_earning_rate; xsparam_x_rate(exp_earning_x); end
  def prove_skill_x; sparam(Feature::SParam::PHARMACOLOGY); end

  # 攻撃速度補正(入力値)
  def attack_speed_rate
    @features_cache[:attack_speed] ||= features_filtered_with(Feature::Code::ATTACK_SPEED, nil, 1.0) {|m, f|
      m + f.value
    }
  end



  # --------------------------------------------------
  # 設定値

  # 特徴
  def features
    @features_cache[:base] ||= features_base
  end

  # 特徴から特定のものを集める
  def features_filtered_with(code, data_id = nil, obj = nil)
    if block_given?
      if data_id
        features.inject(obj) do |memo, feature|
          if feature.code == code && feature.data_id == data_id
            yield(memo, feature)
          else
            memo
          end
        end
      else
        features.inject(obj) do |memo, feature|
          if feature.code == code
            yield(memo, feature)
          else
            memo
          end
        end
      end
    else
      if data_id
        features.select {|feature| feature.code == code && feature.data_id == data_id }
      else
        features.select {|feature| feature.code == code }
      end
    end
  end

  # 特徴にある設定がなされているか
  def featured?(code, data_id = nil, obj = nil)
    if data_id
      features.any? {|feature| feature.code == code && feature.data_id == data_id }
    else
      features.any? {|feature| feature.code == code }
    end
  end

  # 計算後のパラメータ
  def param(id)
    Itefu::Utility::Math.max(1,
      param_base(id) * param_rate1(id) + param_rate2(id)
    ).to_i
  end

  # 基礎値から種々の効果で増えた分
  def param_gained(id)
    param(id) - param_base(id)
  end

  # 整数分-未指定0, 1以上の指定値を加算していく
  def feature_param0(code, id)
    if block_given?
      features_filtered_with(code, id, 0) {|m, f|
        m + ((yield(f) || 0) * 100).to_i
      }
    else
      features_filtered_with(code, id, 0) {|m, f|
        m + (f.value * 100).to_i
      }
    end
  end

  # 小数分-未指定0.0, 1未満の指定値を加算していく
  def feature_param00(code, id)
    if block_given?
      features_filtered_with(code, id, 0.0) {|m, f|
        f.value.abs < 0.01 ? m + ((yield(f) || 0) * 1000) : m
      }
    else
      features_filtered_with(code, id, 0.0) {|m, f|
        f.value.abs < 0.01 ? m + (f.value * 1000) : m
      }
    end
  end

  # 小数分-未指定0, 1未満の指定値を整数とみなして加算する
  def feature_param_n0(code, id)
    if block_given?
      features_filtered_with(code, id, 0) {|m, f|
        f.value.abs < 0.01 ? m + ((yield(f) || 0) * 100000).to_i : m
      }
    else
      features_filtered_with(code, id, 0) {|m, f|
        f.value.abs < 0.01 ? m + (f.value * 100000).to_i : m
      }
    end
  end

  # 乗算-未指定1.0, １未満の指定値を乗算していく
  def feature_param10(code, id)
    if block_given?
      features_filtered_with(code, id, 1.0) {|m, f|
        f.value.abs < 0.01 ? m * ((yield(f) || 0) * 1000) : m
      }
    else
      features_filtered_with(code, id, 1.0) {|m, f|
        f.value.abs < 0.01 ? m * (f.value * 1000) : m
      }
    end
  end

  # 加算-未指定0, 0を-100, 100を0として加算していく
  # 0超1未満は無視する
  def feature_param_n100(code, id)
    if block_given?
      features_filtered_with(code, id, 0) {|m, f|
        f.value.abs >= 0.01 ? m + ((yield(f) || 0) * 100).to_i - 100 : (f.value == 0 ? (yield(f) || 0) -100 : m)
      }
    else
      features_filtered_with(code, id, 0) {|m, f|
        f.value.abs >= 0.01 ? m + (f.value * 100).to_i - 100 : (f.value == 0 ? -100 : m)
      }
    end
  end

  # 加算-未指定0, 0を-100, 100を0として加算していく（小数点記法無視）
  def feature_param100(code, id)
    if block_given?
      features_filtered_with(code, id, 0) {|m, f|
        m + ((yield(f) || 0) * 100).to_i - 100
      }
    else
      features_filtered_with(code, id, 0) {|m, f|
        m + (f.value * 100).to_i - 100
      }
    end
  end

  # 加算値を乗算値に変換する
  def xsparam_x_rate(x)
    (100 + x) / 100.0
  end

  # 乗算: 特徴-通常能力値 ( < 1)
  def param_rate1(id); feature_param10(Feature::Code::PARAM, id); end

  # 加算: 特徴-通常能力値 (1-100)
  def param_rate2(id); feature_param0(Feature::Code::PARAM, id); end

  # 加算: 特徴-追加能力値
  def xparam(id, &block); feature_param0(Feature::Code::XPARAM, id, &block); end

  # 乗算: 特徴-追加能力値
  def xparam_rate(id, &block); feature_param00(Feature::Code::XPARAM, id, &block); end

  # 加算: 特徴-特殊能力値
  def sparam(id); feature_param100(Feature::Code::SPARAM, id); end

  # 乗算: 特徴-特殊能力値
  # def sparam_rate(id); feature_param00(Feature::Code::SPARAM, id); end

  # 装備可能か
  def able_to_equip?(item)
    case item
    when RPG::Weapon
      featured?(Feature::Code::ENABLED_WEAPON_TYPE, item.wtype_id)
    when RPG::Armor
      featured?(Feature::Code::ENABLED_ARMOR_TYPE, item.atype_id)
    else
      ITEFU_DEBUG_OUTPUT_WARNING "an item #{item} is not for equipment"
      false
    end
  end

  # 耐性 [-100_0_100_900]
  alias :resistance :feature_param_n100
  alias :deduction :feature_param_n0

  # 有効度 [2.0_1.0_0.0_0.0]
  def conductance(type_id, id)
    Game::Agency.resistance_to_conductance(resistance(type_id, id))
  end

  # 属性への耐性
  def element_resistance(id)
    resistance(Feature::Code::ELEMENT_RATE, id)
  end

  # 属性への有効度
  def element_conductance(id)
    conductance(Feature::Code::ELEMENT_RATE, id)
  end

  # 属性の軽減
  def element_deduction(id)
    deduction(Feature::Code::ELEMENT_RATE, id)
  end

  # 状態異常への耐性
  def state_resistance(id)
    resistance(Feature::Code::STATE_RATE, id)
  end

  # 状態異常への有効度
  def state_conductance(id)
    conductance(Feature::Code::STATE_RATE, id)
  end

  # 状態異常の軽減
  # def state_deduction(id)
  #   deduction(Feature::Code::STATE_RATE, id)
  # end

  # 弱体化への耐性
  def debuff_resistance(id)
    resistance(Feature::Code::DEBUFF_RATE, id)
  end

  # 弱体化への有効度
  def debuff_conductance(id)
    conductance(Feature::Code::DEBUFF_RATE, id)
  end

  # 弱体化の軽減
  # def debuff_deduction(id)
  #   deduction(Feature::Code::DEBUFF_RATE, id)
  # end

  # @return [Hash<Feature>] 攻撃時ステート
  def attack_state_ids
    unless @features_cache[:attack_state_ids]
      obj = Hash.new(0)
      features_filtered_with(Feature::Code::ATTACK_STATE, nil, obj) {|memo, feature|
        memo[feature.data_id] += (feature.value * 100).to_i
        memo
      }
      @features_cache[:attack_state_ids] = obj
    end
    @features_cache[:attack_state_ids]
  end

  # [通常攻撃]の属性値
  # @return [Hash] 設定されている属性とその数
  def attack_element_ids
    @features_cache[:attack_element_id] ||= attack_element_ids_impl
  end

  def attack_element_ids_impl
    elements = features_filtered_with(Feature::Code::ATTACK_ELEMENT, nil, Hash.new(0)) {|m, f|
      if f.data_id > 0
        m[f.data_id] += 1
      end
      m
    }
    if elements.empty?
      elements[0] = 0
    end
    elements
  end
  private :attack_element_ids_impl

  # 属性攻撃の威力 (0～...)
  def attack_element_level(element_id)
    elements = attack_element_ids
    elements[element_id] || 0
  end

  # [通常攻撃]のアニメーション(物理攻撃用)
  def attack_animation_id
    f = features.reverse_each.find {|feature|
      feature.code == Feature::Code::ATTACK_ELEMENT &&
        # @magic 物理属性
        feature.data_id == 1 ||
        feature.data_id == 2 ||
        feature.data_id == 3
    }
    # @magic 属性に対応するアニメーションのID
    case f && f.data_id
    when 1
      # 斬撃
      7
    when 2
      # 刺突
      13
    when 3
      # 殴打
      19
    else
      # 格闘
      1
    end
  end

  # スキルタイプ封印がされているか
  def skill_type_disabled?(type_id)
    featured?(Feature::Code::DISABLED_SKILL_TYPE, type_id)
  end

  # スキルが封印されているか
  def skill_disabled?(skill_id)
    featured?(Feature::Code::DISABLED_SKILL, skill_id)
  end

  # 使用できるスキルか
  def skill_usable?(skill)
    skill_type_disabled?(skill.stype_id).!
  end

  # 耐性のあるステートか
  def resisted_state?(state_id)
    featured?(Feature::Code::RESISTED_STATE, state_id)
  end

  # 行動追加係数
  # @return [FixNum] 100ごとに1回分確定で行動を追加する
  def additional_move_x
    feature_param0(Feature::Code::ADDITIONAL_ACTION_RATE, 0)
  end

  # 行動追加回数
  def additional_move_count
    additional_move_x / 100
  end

  # 防御中か
  def defence?
    featured?(Feature::Code::SPECIAL_FLAG, Feature::SpecialFlag::GUARD)
  end

  # ふんばり中＝防御が重ねがけされているか
  def endurance?(assure_defence = false)
    (assure_defence || defence?) && features.one? {|feature| feature.code == Feature::Code::SPECIAL_FLAG && feature.data_id == Feature::SpecialFlag::GUARD }.!
  end


  # 自動戦闘中か
  def auto_battle?
    featured?(Feature::Code::SPECIAL_FLAG, Feature::SpecialFlag::AUTO_BATTLE)
  end

  # 消滅エフェクト
  # @note 一番最後に指定されたものを優先する
  def collapse_type
    f = features.reverse_each.find {|feature|
      feature.code == Feature::Code::COLLAPSE_TYPE
    }
    f && f.data_id || Feature::CollapseType::NONE
  end

  # パーティ能力が有効か
  def party_ability?(ability_id)
    featured?(Feature::Code::PARTY_ABILITY, ability_id)
  end

  # エンカウント半減か
  def encounter_half?; party_ability?(Feature::PartyAbility::ENCOUNTER_HALF); end
  # エンカウント無効か
  def encounter_none?; party_ability?(Feature::PartyAbility::ENCOUNTER_NONE); end
  # 獲得金額二倍か
  def gold_double?; party_ability?(Feature::PartyAbility::GOLD_DOUBLE); end
  # アイテム獲得チャンス二倍か
  def drop_item_double?; party_ability?(Feature::PartyAbility::DROP_ITEM_DOUBLE); end
  # 逃走に必ず成功するか
  def escape_surely?; party_ability?(Feature::PartyAbility::CANCEL_SURPRISE); end
  # リジェネ無効化
  def regeneration_disabled?; party_ability?(Feature::PartyAbility::RAISE_PREEMPTIVE); end 
end


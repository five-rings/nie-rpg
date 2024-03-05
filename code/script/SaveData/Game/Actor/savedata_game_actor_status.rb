=begin 
  パーティメンバーのステータス
=end
module SaveData::Game::Actor::Status
  include SaveData::Game::Actor::State
  include SaveData::Game::Actor::Buff
  include SaveData::Game::Actor::Feature
  attr_reader :life   # hpバーの個数   HP × life = 実際のHP
  attr_reader :hp
  attr_reader :mp

  def initialize(*args)
    super
    clear_add_params
    recover_all
  end

  # 追加でスキルを習得する
  def learn_skill(skill_id); end

  # ステート変更時のキャッシュクリア
  def clear_state_cache
    super
    clear_features_cache
  end

  # ステート付与
  def add_state(*args)
    if alive?
      super
    end
  end

  # Particural State
  def alive?; dead?.!; end
  def dead?; in_state_of?(Itefu::Rgss3::Definition::State::DEAD); end
  def immortal?; resisted_state?(Itefu::Rgss3::Definition::State::DEAD); end
  def mortal?; immortal?.!; end
  def uncontrollable?
    auto_battle? || super
  end


  # --------------------------------------------------
  # 設定値

  def attack; (super * param_scale(:attack_scale)).to_i; end
  alias :atk :attack
  def defence; (super * param_scale(:defence_scale)).to_i; end
  alias :def :defence
  def footwork; (super * param_scale(:footwork_scale)).to_i; end
  alias :act :footwork
  def accuracy; (super * param_scale(:accuracy_scale)).to_i; end
  alias :hit :accuracy
  def evasion; (super * param_scale(:evasion_scale)).to_i; end
  alias :eva :evasion
  def magic; (super * param_scale(:magic_scale)).to_i; end
  alias :mag :magic

  def max_hp; (super * param_scale(:mhp_scale)).to_i; end
  alias :mhp :max_hp
  def max_mp; (super * param_scale(:mmp_scale)).to_i; end
  alias :mmp :max_mp

  def luck; (super * param_scale(:luck_scale)).to_i; end
  alias :luk :luck
  def hpr; (super * param_scale(:hpr_scale)).to_i; end
  def mpr; (super * param_scale(:mpr_scale)).to_i; end


  # --------------------------------------------------
  # ステータス操作

  # 全回復する
  def recover_all
    clear_states
    clear_all_debuffs
    recover_points
  end

  def recover_points
    @hp = mhp
    @mp = mmp
  end

  # 死亡状態にする
  def die
    clear_states
    add_state(Itefu::Rgss3::Definition::State::DEAD)
    @hp = 0
  end

  # 生き返らせる
  def revive(hp)
    remove_state(Itefu::Rgss3::Definition::State::DEAD)
    @hp = Itefu::Utility::Math.clamp(1, mhp, hp)
  end


  # 自動回復文だけHPを回復する
  def recover_hp
    hpr.tap {|v| add_hp(v) }
  end

  # 回復分だけの自動回復
  def take_hpr_positive
    hpr_positive.tap {|v| add_hp(v) }
  end

  # スリップダメージを受ける
  def take_hpr_negative
    hpr_negative.tap {|v| add_hp(v) }
  end

  # 自動回復分だけMPを回復する
  def recover_mp
    mpr.tap {|v| add_mp(v) }
  end

  # @param [Fixnum] value 増減値。ダメージの場合はマイナスの値を与える。
  # @param [Boolean] mortal ダメージを受けた場合に死亡するか
  def add_hp(value, mortal = true)
    return if dead?

    @hp += value
    if @hp <= 0
      unless immortal?
        die if mortal
      end
      @hp = 1 unless dead?
    end

    @hp = Itefu::Utility::Math.clamp(0, mhp, @hp)
  end

  # HP全快か？
  def hp_full?; hp == mhp; end

  # @param [Fixnum] value 増減値。消費の場合はマイナスの値を与える。
  def add_mp(value)
    return if dead?

    @mp += value
    @mp = Itefu::Utility::Math.clamp(0, mmp, @mp)
  end

  # MP全快か？
  def mp_full?; mp == mmp; end

  # [成長] 能力を固定値分増やす
  def add_param(param_id, value)
    @param_plus[param_id] += value
  end

  # 増減した能力の初期化
  def clear_add_params
    @param_plus = [0] * 8
  end



  # --------------------------------------------------
  # 設定値

  # 特徴を設定できる各種項目から特徴を集める
  def features_base(obj = [])
    db = Application.database.states
    states.each_with_object(obj) {|id, memo|
      memo.concat db[id].features
    }
    obj
  end

  # 基礎値
  def param_base(id)
    param_plus(id) + param_buff(id)
  end

  # バフ／デバフでの補正値
  def param_buff(id)
    c = buff_count(id) - debuff_count(id)
    c * 5
  end

  # 加算: 成長値
  def param_plus(id)
    @param_plus[id]
  end

end


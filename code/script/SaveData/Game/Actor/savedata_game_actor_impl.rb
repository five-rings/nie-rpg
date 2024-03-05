=begin
  パーティメンバーのパラメータ
=end
class SaveData::Game::Actor
  include Level
  include Status
  include Equipment
  attr_reader :actor_id
  attr_reader :class_id
  attr_reader :skills
  alias :skills_raw :skills
  attr_accessor :name, :nickname
  attr_accessor :chara_name, :chara_index
  attr_accessor :face_name, :face_index

  def initialize(actor_id)
    @actor_id = actor_id
    @class_id = actor.class_id
    @skills = []
    super
    add_default_equipments
    recover_all
  end

  def actor; Application.database.actors[@actor_id]; end
  alias :battler :actor
  def initial_level; actor.initial_level; end
  def max_level; actor.max_level; end
  def level_table_id; actor.class_id; end

  def name; @name || actor.name; end
  def nickname; @nickname || actor.nickname; end
  def chara_name; @chara_name || actor.character_name; end
  def chara_index; @chara_index || actor.character_index; end
  def face_name; @face_name || actor.face_name; end
  def face_index; @face_index || actor.face_index; end

  def actor_class; Application.database.classes[@class_id]; end
  alias :job :actor_class
  def job_name;
    case @job_name
    when Fixnum
      job.special_flag(:job_name)[@job_name]
    else
      @job_name
    end || job.name
  end



  # HP/MPを最大値の範囲に収める
  def clamp_hp_mp
    @hp = Itefu::Utility::Math.clamp(1, mhp, @hp) if @hp
    @mp = Itefu::Utility::Math.clamp(0, mmp, @mp) if @mp
  end

  # 自動HP/MP補正を一時的に無効にする
  def no_auto_clamp
    @no_auto_clamp = true
    yield
    @no_auto_clamp = false
  end

  # 特徴が変わった際のリセット処理
  def clear_features_cache
    super
    clamp_hp_mp unless @no_auto_clamp
  end

  # 装備の変更
  def equip(*args)
    ret = super
    clear_features_cache
    ret
  end

  # 非デフォルト枠でない場合枠ごと削除
  def remove_equip(*args)
    ret = super
    clear_features_cache
    ret
  end

  # ジョブの変更
  def change_class(class_id)
    return unless myclass = Application.database.classes[class_id]
    @class_id = class_id
    clear_features_cache
    class_id
  end
  alias :change_job :change_class

  # ジョブの名称のみ上書き変更する
  # @note nilで元に戻す
  def change_class_name(name)
    @job_name = name
  end
  alias :change_job_name :change_class_name

  # レベルアップでの回復
  def recover_by_leveling_up(old_level)
    if @level > old_level
      current_level = @level
      @level = old_level
      old_mhp = self.mhp
      old_mmp = self.mmp
      @level = current_level
      # レベルアップでの上昇分だけ回復
      self.add_hp(self.mhp - old_mhp)
      self.add_mp(self.mmp - old_mmp)
    end
  end


  # --------------------------------------------------
  # 設定値

  def features_base
    obj = []
    super(obj)
    @equipments.values.each_with_object(obj) {|equip, memo|
      memo.concat(equip.features) if equip
    }
    obj.concat actor.features
    obj.concat actor_class.features
    obj
  end

  # 職とレベルで決まる固有値
  def param_base(id)
    super + actor_class.params[id, level]
  end

  alias :param_raw :param
  def param(id)
    super + param_equip(id)
  end

  def param_gained(id)
    param_raw(id) - param_base(id)
  end

  # 装備品の設定値 # Atkとか最後に足されるもの
  def param_equip(id)
    @equipments.values.inject(0) {|memo, equip|
      memo + (equip && equip.params[id] || 0)
    }
  end


  def attack_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::ATTACK); end
  def defence_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::DEFENCE); end
  def footwork_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::AGILITY); end
  def accuracy_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::MAGIC_DEFENCE); end
  def evasion_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::LUCK); end
  def magic_raw; param_raw(Itefu::Rgss3::Definition::Status::Param::MAGIC_ATTACK); end

  def attack_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::ATTACK); end
  def defence_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::DEFENCE); end
  def footwork_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::AGILITY); end
  def accuracy_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::MAGIC_DEFENCE); end
  def evasion_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::LUCK); end
  def magic_equip; param_equip(Itefu::Rgss3::Definition::Status::Param::MAGIC_ATTACK); end

  # 装備品のみの幸運値
  def luck_equip
    @features_cache[:luck_equip] ||= @equipments.values.inject(0) {|memo, equip|
      if equip
        equip.features.inject(memo) {|memo2, feature|
          if feature.code == Itefu::Rgss3::Definition::Feature::Code::XPARAM && feature.data_id == Itefu::Rgss3::Definition::Feature::XParam::CRITICAL_RATE
            # xparamと同じ計算
            memo2 + (feature.value * 100).to_i
          else
            memo2
          end
        }
      else
        memo
      end
    }
  end

  # 装備品のみの狙われ値
  def hate_equip
    @features_cache[:hate_equip] ||= @equipments.values.inject(0) {|memo, equip|
      if equip
        equip.features.inject(memo) {|memo2, feature|
          if feature.code == Itefu::Rgss3::Definition::Feature::Code::SPARAM && feature.data_id == Itefu::Rgss3::Definition::Feature::SParam::HATE_RATE
            # sparamと同じ計算
            memo2 + (feature.value * 100).to_i - 100
          else
            memo2
          end
        }
      else
        memo
      end
    }
  end

  # 職業/アクター分のみの狙われ値
  def hate_raw
    @features_cache[:hate_raw] ||= self.hate - self.hate_equip
  end

  # --------------------------------------------------
  # ステート関連

  # 耐性のついたステートを耐性値が大きい順に返す
  def proofed_states
    db_states = Application.database.states
    resists = db_states.map {|state| state && state_resistance(state.id) }
    db_states.select {|state|
      state && resists[state.id] > 0
    }.sort_by {|state|
      resists[state.id]
    }.reverse
  end

  # 無効なステートを返す（MyConfigで指定した表示対象のもののみ）
  def immuned_states
    @features_cache[:immuned_states] ||= Application.config.immuned_states.select {|state_id|
      resisted_state?(state_id)
    }
  end

  # --------------------------------------------------
  # スキル関連

  def learnings
    if @learnings
      actor_class.learnings + @learnings
    else
      actor_class.learnings
    end
  end

  def skill_diffs(old_skills)
    diffs = self.skills_raw - old_skills
    db_skills = Application.database.skills
    diffs.select! {|sid|
      skill = db_skills[sid]
      skill && skill.special_flag(:no_notice).!
    }
    diffs
  end

  # スキル習得テーブルにスキルを追加する
  # @note levelがnilの場合、次のレベルで覚える
  def add_skill_to_learnings(skill_id, level = nil)
    learning = RPG::Class::Learning.new
    learning.level = level || (@level + 1)
    learning.skill_id = skill_id
    @learnings ||= []
    @learnings.push learning unless @learnings.include?(learning)
    learning
  end

  # レベルアップ時にスキルを取得する
  def add_level(value = 1)
    old_level = @level
    ret_val = super
    if newjoblevel = self.job.highjob_name(@level, old_level, false)
      change_job_name(newjoblevel)
    end
    learnings.each do |learning|
      next if @forgotten_skills && @forgotten_skills.include?(learning.skill_id)
      learn_skill(learning.skill_id) if learning.level <= @level
    end
    self.job.skill_deleting_each(@level, old_level) do |level, skills|
      skills.each do |sid|
        forget_skill(sid)
      end
    end
    ret_val
  end

  # 強制的にスキルを覚える
  def learn_skill(skill_id)
    unless @skills.include?(skill_id)
      @features_cache[:skills] = nil
      @skills.push(skill_id)
      @forgotten_skills.delete(skill_id) if @forgotten_skills
      # replace_shortcut(skill_id)
    end
  end

  # 覚えたスキルを強制的に忘れる
  def forget_skill(skill_id)
    @forgotten_skills ||= []
    @forgotten_skills << skill_id
    @forgotten_skills.uniq!

    @features_cache[:skills] = nil
    @skills.delete(skill_id)
  end

  # スキル一覧
  def skills
    unless @features_cache[:skills] 
      obj = @features_cache[:skills] = []
      obj.concat @skills
      # スキル追加
      features_filtered_with(Itefu::Rgss3::Definition::Feature::Code::ENABLED_SKILL, nil, obj) do |memo, feature|
        memo << feature.data_id
      end
      # スキル封印
      features_filtered_with(Itefu::Rgss3::Definition::Feature::Code::DISABLED_SKILL, nil, obj) do |memo, feature|
        memo.delete(feature.data_id)
        memo
      end
      # 重複を除外
      obj.uniq!
    end
    @features_cache[:skills]
  end


private

  # --------------------------------------------------
  # 装備関連

  # 初期装備の取得
  def add_default_equipments
    weapons = Application.database.weapons
    armors = Application.database.armors

    equip(Definition::Game::Equipment::Type::RIGHT_HAND, weapons[self.actor.equips[Itefu::Rgss3::Definition::Equipment::Slot::WEAPON]])
    equip(Definition::Game::Equipment::Type::LEFT_HAND, armors[self.actor.equips[Itefu::Rgss3::Definition::Equipment::Slot::SHIELD]])
    equip(Definition::Game::Equipment::Type::HEAD, armors[self.actor.equips[Itefu::Rgss3::Definition::Equipment::Slot::HEAD]])
    equip(Definition::Game::Equipment::Type::BODY, armors[self.actor.equips[Itefu::Rgss3::Definition::Equipment::Slot::BODY]])
    equip(Definition::Game::Equipment::Type::ACCESSORY_A, armors[self.actor.equips[Itefu::Rgss3::Definition::Equipment::Slot::ACCESSORY]])
  end

end


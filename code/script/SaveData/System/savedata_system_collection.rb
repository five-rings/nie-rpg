=begin
  システムデータ/セーブデータをまたぐコレクション
=end
class SaveData::System::Collection
  attr_accessor :enemies

  def initialize
    self.enemies = {}
  end

  def discover_enemy(enemy_id)
    @enemies[enemy_id] = EnemyData.new unless @enemies.has_key?(enemy_id)
  end

  def enemy_data(enemy_id)
    @enemies[enemy_id]
  end

  def prove_enemy_skill(enemy_id, skill_id)
    if @enemies.has_key?(enemy_id)
      @enemies[enemy_id].prove_skill(skill_id)
    end
  end

  def enemy_skill_proved?(enemy_id, skill_id)
    @enemies.has_key?(enemy_id) && @enemies[enemy_id].skill_proved?(skill_id)
  end

  def encounter_enemy(enemy_id)
    if @enemies.has_key?(enemy_id)
      @enemies[enemy_id].encounter
    end
  end

  def enemy_encountering_count(enemy_id)
    @enemies.has_key?(enemy_id) && @enemies[enemy_id].count_to_encounter || 0
  end

  def enemy_encountered?(enemy_id)
    @enemies.has_key?(enemy_id) && @enemies[enemy_id].encountered?
  end

  def defeat_enemy(enemy_id)
    if @enemies.has_key?(enemy_id)
      @enemies[enemy_id].defeat
    end
  end

  def enemy_defeating_count(enemy_id)
    @enemies.has_key?(enemy_id) && @enemies[enemy_id].count_to_defeat || 0
  end

  def enemy_defeated?(enemy_id)
    @enemies.has_key?(enemy_id) && @enemies[enemy_id].defeated?
  end

  def enemy_known?(enemy_id)
    # 倒しているなら既知
    return true if enemy_defeated?(enemy_id)
    # 別途指定のあるものも既知と扱う
    enemies = Application.database.enemies
    if enemies && (e = enemies[enemy_id])
      # :known
      case v = e.special_flag(:known)
      when true
        # 最初から既知扱い
        return true
      when Fixnum
        # 指定回数遭遇で既知扱い
        return true if v <= enemy_encountering_count(enemy_id)
      end
    end
    # 詳しくしらない敵
    false
  end

  class EnemyData
    attr_reader :skill_flags
    attr_reader :count_to_defeat
    attr_reader :count_to_encounter
    attr_accessor :triumphed

    def initialize
      @count_to_defeat = 0
      @count_to_encounter = 0
      @skill_flags = Hash.new(false)
    end

    def skill_proved?(skill_id)
      skill_flags[skill_id]
    end

    def prove_skill(skill_id)
      skill_flags[skill_id] = true
    end

#ifdef :ITEFU_DEVELOP
    # 古いセーブデータ対策
    def count_to_encounter
      @count_to_encounter || 0
    end
#endif

    def encounter
#ifdef :ITEFU_DEVELOP
      @count_to_encounter ||= 0 # 古いセーブデータ対策
#endif
      @count_to_encounter += 1
    end

    def encountered?
#ifdef :ITEFU_DEVELOP
      @count_to_encounter &&  # 古いセーブデータ対策
#endif
      @count_to_encounter > 0
    end

    def defeat
      @count_to_defeat += 1
    end

    def defeated?
      @count_to_defeat > 0
    end
  end

end

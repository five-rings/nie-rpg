=begin
  パーティメンバーのレベル
=end
module SaveData::Game::Actor::Level
  attr_reader :level
  attr_reader :total_exp
  attr_reader :level_table_id
  
  def initial_level; raise Itefu::Exception::NotImplemented; end
  def max_level; raise Itefu::Exception::NotImplemented; end
  
  def initialize(*args)
    @level = 0
    @total_exp = 0
    add_level(initial_level)
    super
  end
  
  def copy_from(src)
    @level = src.level
    @total_exp = src.total_exp
    @level_table_id = src.level_table_id
    self
  end
  
  # @return [Fixnum] 特定のレベルになるのに必要な取得経験値量
  # @param [Fixnum] level 必要な経験値を調べたいレベル
  def exp_for_level(level)
    return Float::INFINITY if level > max_level
    return unless classes = Itefu::Database.table(:classes)
    return unless entry = classes[self.level_table_id]
    entry.exp_for_level(level)
  end
  
  # @return [Fixnum] 今のレベルになるのに必要な取得経験値量
  def exp_for_current_level
    exp_for_level(@level)
  end

  # @return [Fixnum] 次のレベルになるのに必要な取得経験値量
  def exp_for_next_level
    exp_for_level(@level + 1)
  end
  
  # @return [Fixnum] 今のレベルになってからたまった経験値
  def exp
    total_exp - exp_for_current_level
  end
  
  # @return [Fixnum] 今のレベルから次のレベルになるのに必要な経験値
  def exp_next
    exp_for_next_level - exp_for_current_level
  end
  
  # @param [Fixnum] exp 追加する経験値
  # @note 自動的にレベルアップも行う
  # @note 経験値を減らすこともできるがレベルダウンは行わない
  def add_exp(exp)
    @total_exp += exp
    while @total_exp >= exp_for_next_level
      add_level
    end
  end
  
  # @param [Fixnum] value　レベルを増減させる量
  # @note レベルが変わった場合、取得経験値をそのレベルになるための量に合わせる
  def add_level(value = 1)
    return if value == 0
    @level = Itefu::Utility::Math.min(max_level, @level + value)
    @total_exp = Itefu::Utility::Math.max(@total_exp, exp_for_current_level)
  end
  
  # 経験値を足し、レベルアップできるときはレベルを1だけ上げ、余ったEXPを返す
  # @return [Fixnum] 余ったExp. レベルが上がらなかった場合は0を返す
  # @param [Fixnum] exp 追加する経験値
  # @note レベルが上がった場合、取得経験値はexp分だけ増えず、上がったレベルに必要な量になる
  def gain_exp(exp)
    @total_exp += exp
    remain = @total_exp - exp_for_next_level
    if remain >= 0
      add_level
      remain
    else
      0
    end
  end

end

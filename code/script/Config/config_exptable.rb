=begin
  経験値テーブルの外部読み込み
=end
class Config::ExpTable
  include Itefu::Config

class << self
  def instance; @@instance; end
  def load; @@instance = self.new.load(Filename::Config::EXPTABLE); end
end

  # @param [Fixnum] class_id 置き換える対象の職業ID
  # @param [Array] table 次のレベルになるのに必要な経験値の表
  def exp_table(class_id, table)
    memo = 0
    # 累計に変換する
    @exp_table[class_id] = table.map! {|exp|
        memo += exp
      }
    self
  end

  # @return [Fixnum] level になるのに必要な累計経験値
  # @param [Fixnum] class_id 対象の職業ID
  # @param [Fixnum] level 必要経験値量を確かめたいレベル
  def exp_for_level(class_id, level)
    level >= 2 && (t = @exp_table[class_id]) && t[level - 2]
  end

  def load(file, *args)
    super
  rescue => e
    ITEFU_DEBUG_OUTPUT_WARNING "Failed to load exptable file '#{file}'"
    ITEFU_DEBUG_OUTPUT_WARNING e
    self
  end

private
  def initialize
    @exp_table = {}
  end
end

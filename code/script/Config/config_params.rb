=begin
  能力値の外部読み込み
=end
class Config::Params
  include Itefu::Config

class << self
  def instance; @@instance; end
  def load; @@instance = self.new.load(Filename::Config::PARAMS); end
end

  # @param [Fixnum] actor_id 置き換える対象のアクターID
  # @param [Array<Array>] table レベルごとの能力値表
  def params_table(actor_id, table)
    @params_table[actor_id] = table
    self
  end

  # @return [Fixnum] level になるのに必要な累計経験値
  # @param [Fixnum] actor_id 対象の職業ID
  # @param [Fixnum] id 能力の識別子
  # @param [Fixnum] level 能力値を取得したいレベル
  def params(actor_id, id, level)
    level >= 1 && (t = @params_table[actor_id]) && (t = t[level - 1]) && t[id]
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
    @params_table = {}
  end
end

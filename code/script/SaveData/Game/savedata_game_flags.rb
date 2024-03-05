=begin
  スイッチ/セルフスイッチ/変数のデータ  
=end
class SaveData::Game::Flags < SaveData::Game::Base
  attr_reader :switches
  attr_reader :self_switches
  attr_reader :variables
  
  def initialize
    @switches = Switches.new
    @self_switches = SelfSwitches.new
    @variables = Variables.new
    switch_on_by_system
  end

  def on_load
    switch_on_by_system
  end

  # システムデータと連動してスイッチをオンにする
  def switch_on_by_system
    { end_b: 62,
      defeat_veinglad: 63,
      end_c: 64,
    }.each do |system, game|
      @switches[game] = true if Application.savedata_system.flags[system]
    end
  end

  # ニエとの親密さ
  def nie_intimacy
    @variables[100]
  end

  # ニエと十分に親密か
  def nie_intimate?
    nie_intimacy >= Application.config.nie_intimacy_love
  end
  
  # ニエにプレゼントを贈れば親密になれる状態か
  def nie_far_intimate?
    num_present = Database.num_present    # プレゼントイベントの数
    num_present_consumed = @variables[79] # プレゼント消費数
    nie_intimacy + num_present - num_present_consumed < Application.config.nie_intimacy_love
  end

  # ニエとのフラグが立っているか
  def nie_flagged?
    @variables[141] >= 1 &&       # テナン発展度
    @switches[167] &&             # 冒険者の証を取得
    # @variables[163] >= 2 &&       # アザレア発展度
    @switches[182] &&             # 冒険者の酒場チェック済み
    @switches[218] &&             # アザレアクリア（通行証使用）
    # @switches[231] &&             # シトレアの髪飾り
    @switches[235] &&             # 手を取って瀬渡し
    # @switches[248] &&             # 湖畔土くれ=ユベシア側から到達
    # @variables[174] & 0b1 != 0 && # アザレア民俗学者: エルクの花向け
    true
  end

  # トゥルーエンド条件を満たしているか
  def nie_fell_in_love?
    nie_flagged? &&
    nie_intimate?
  end

  # エンディングまで到達したか
  def ended?
    @switches[4]
  end

  # エンディングの種類
  def ending_type
    @variables[97]
  end

  # エンディングの種類を設定する
  def ending_type=(value)
    @variables[97] = value
  end

  # 戦闘中のターン数
  def turn_count
    @variables[66]
  end

  # 戦闘中のターン数を設定する
  def turn_count=(count)
    @variables[66] = count
  end
  
  class Switches
    attr_reader :data
    def initialize; @data = Hash.new(false); end
    def []=(index, rhs); @data[index] = rhs; end
    def [](index); @data[index]; end
  end
  
  class SelfSwitches
    attr_reader :data
    def initialize; @data = Hash.new(false); end
    def []=(map_id, event_id, index, rhs); @data[key(map_id, event_id, index)] = rhs; end
    def [](map_id, event_id, index); @data[key(map_id, event_id, index)]; end
  private
    def key(*args); args; end
  end
  
  class Variables
    attr_reader :data
    def initialize; @data = Hash.new(0); end
    def []=(index, rhs); @data[index] = rhs; end
    def [](index); @data[index]; end
  end

end

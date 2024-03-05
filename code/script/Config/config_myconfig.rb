=begin
  外部から読み込む設定ファイル
=end
class Config::MyConfig
  include Itefu::Config
  # システム
  attr_accessor :screen_width, :screen_height
  attr_accessor :locale
  # その他
  attr_accessor :nie_intimacy_love
  # 戦闘関連
  attr_accessor :speed_rand, :critical_rate, :weak_rate, :block_threshold
  attr_accessor :phit_base, :mhit_base
  attr_accessor :hate_in_dead
  attr_accessor :skill_id_enemy_uncontrolled
  attr_accessor :battle_effect_actor, :battle_effect_enemy
  attr_accessor :battle_chiritori_count, :battle_chiritori_anime
  attr_accessor :immuned_states
  attr_accessor :version

  def initialize
    screen_size(544, 416)
    self.nie_intimacy_love = 24
    # 戦闘関連
    self.speed_rand = proc {|base| 11 }
    self.critical_rate = 1.5
    self.weak_rate = 1.5
    self.block_threshold = 0.76
    self.phit_base = self.mhit_base = 100
    self.hate_in_dead = 0
    self.skill_id_enemy_uncontrolled = 1
    self.battle_effect_actor = self.battle_effect_enemy = 1.0
    self.battle_chiritori_count = proc {}
    self.battle_chiritori_anime = proc {}
    self.immuned_states = []
  end
  
  def screen_size(w, h)
    @screen_width  = w
    @screen_height = h
  end

  def load(file, *args)
    super
  rescue => e
    ITEFU_DEBUG_OUTPUT_WARNING "Failed to load config file '#{file}'"
    ITEFU_DEBUG_OUTPUT_WARNING e
    self
  end

end

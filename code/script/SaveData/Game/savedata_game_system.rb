=begin
  分割しづらい全体に関わるようなデータ
  ただしHeaderに記載するものは除く
=end
class SaveData::Game::System < SaveData::Game::Base
  attr_accessor :save_slot        # [Fixnum|NilClass] 
  attr_accessor :embodied         # [Boolean] 初回起動時の演出を行ったか
  attr_accessor :count_of_steps   # [Fixnum] 歩数
  attr_accessor :count_of_saving  # [Fixnum] セーブ回数
  attr_accessor :count_of_battle  # [Fixnum] 戦闘回数
  attr_accessor :cached_bgm       # BGM保存用
  attr_accessor :battle_bgm       # 戦闘BGM
  attr_accessor :battle_me        # 戦闘終了ME
  attr_accessor :battle_floor     # 戦闘背景（床）の上書き
  attr_accessor :battle_wall      # 戦闘背景（壁）の上書き
  attr_accessor :battle_cursor    # [Color|NilClass] 戦闘のカーソル色
  attr_accessor :to_save          # [Boolean] セーブできるか
  attr_accessor :to_open_menu     # [Boolean] メニューを開けるか
  attr_accessor :to_encounter     # [Boolean] エンカウントできるか
  attr_accessor :to_go_home       # [Boolean] 拠点へ帰還できるか
  attr_accessor :not_to_discard   # [Boolean] アイテムを捨てるのを禁止するか（並び替え許可を流用）
  attr_accessor :slot_of_weapon   # [Fixnum] 武器に装着可能な枠数
  attr_accessor :slot_of_armor    # [Fixnum] 防具に装着可能な枠数
  attr_accessor :max_embed_weapon # [Fixnum] 武器スロットに装着可能な個数
  attr_accessor :max_embed_armor  # [Fixnum] 防具スロットに装着可能な個数
  attr_accessor :magic_scroll_level # [Fixnum] 不思議な巻物／冊子のレベル
  
  def initialize
    self.count_of_steps = 0
    self.count_of_saving = 0
    self.count_of_battle = 0
    reset
  end
  
  # ゲーム開始時の状態に戻す
  def reset
    reset_instance_variable(:@save_slot)
    self.embodied = false
    self.to_open_menu = false
    self.to_save = true
    self.to_encounter = true
    self.to_go_home = true
    self.not_to_discard = false
    reset_instance_variable(:@cached_bgm)
    reset_instance_variable(:@battle_bgm)
    reset_instance_variable(:@battle_me)
    reset_instance_variable(:@battle_floor)
    reset_instance_variable(:@battle_wall)
    self.slot_of_weapon = Definition::Game::Equipment::Extra::DEFAULT_SLOT_OF_WEAPON
    self.slot_of_armor = Definition::Game::Equipment::Extra::DEFAULT_SLOT_OF_ARMOR
    self.max_embed_weapon = Definition::Game::Equipment::Extra::DEFAULT_MAX_TO_EMBED_TO_WEAPON
    self.max_embed_armor = Definition::Game::Equipment::Extra::DEFAULT_MAX_TO_EMBED_TO_ARMOR
    self.magic_scroll_level = 0
  end

#ifdef :ITEFU_DEVELOP
  def reset_for_debug_play
    reset
    self.embodied = true
    self.to_open_menu = true
  end
#endif
  
  def battle_bgm
    # 未設定時システムデフォルトを返す
    @battle_bgm || Application.database.system.rawdata.battle_bgm
  end
  
  def battle_me
    # 未設定時システムデフォルトを返す
    @battle_me || Application.database.system.rawdata.battle_end_me
  end

  def max_embed_weapon=(value)
    @max_embed_weapon = Itefu::Utility::Math.min(value, Definition::Game::Equipment::Extra::LIMIT_TO_EMBED_TO_WEAPON)
  end

  def slot_of_weapon=(value)
    @slot_of_weapon = Itefu::Utility::Math.min(value, Definition::Game::Equipment::Extra::LIMIT_SLOT_OF_WEAPON)
  end

  def slot_of_armor=(value)
    @slot_of_armor = Itefu::Utility::Math.min(value, Definition::Game::Equipment::Extra::LIMIT_SLOT_OF_ARMOR)
  end

private

  def reset_instance_variable(name)
    if instance_variable_defined?(name)
      remove_instance_variable(name)
    end
  end

end

=begin
  マップ関連の進行データ
=end
class SaveData::Game::Map < SaveData::Game::Base
  attr_accessor :map_id   # [Fixnum] 最後にいたマップID
  attr_accessor :fairy_map_id   # [Fixnum] 最後にいたマップの帰還先ID
  attr_accessor :map_name # [String] 最後にいたマップ名
  attr_accessor :chapter  # [String] 章題
  attr_accessor :to_show_name # [Boolean] マップ名を表示するか
  # [Hash] マップの状態を復元するための諸情報
  attr_accessor :resuming_context
  
  def initialize
    system = Application.database.system.rawdata
    self.map_id = system.start_map_id
    self.map_name = ""
    self.to_show_name = true
    self.resuming_context = {}
    Map.setup_followers(self.resuming_context, system.opt_followers)
    Map.setup_player_graphic(self.resuming_context, system.party_members[0])
    setup_start_position(system.start_x, system.start_y)
  end
  
  # 新規にゲームを開始する場所に移動する
  def reset_to_start_position
    self.map_id = 3     # @magic ゲームの開始地点
    Map.setup_start_position(self.resuming_context, 0, 0)
  end
  
  # マップの再開用のデータを初期化する
  def reset_resuming_context
    self.resuming_context.clear
  end

  def cell_xy_from_resuming_context
    return unless mycontext = self.resuming_context[:manager]
    return unless mycontext = mycontext[Map::Unit::Player.unit_id]
    return mycontext[:@cell_x], mycontext[:@cell_y]
  end

  def setup_start_position(cell_x, cell_y, dir = nil)
    Map.setup_start_position(self.resuming_context, cell_x, cell_y, dir)
  end

end

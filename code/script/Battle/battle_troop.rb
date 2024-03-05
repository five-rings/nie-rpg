=begin
  戦闘中の敵集団情報
=end
class Battle::Troop
  attr_reader :troop_id
  attr_reader :enemies

  def initialize(troop_id, screen_width)
    @troop_id = troop_id
    @enemies = []
    @screen_width = screen_width
  end

  def setup_from_database(db_troops, db_enemies)
    @troop = db_troops[@troop_id]
    @db_enemies = db_enemies
    @troop.members.each do |member|
      add_enemy(member.enemy_id, member.x, member.y + 14, member.hidden)
    end
  end

  # 敵を追加する
  def add_enemy(enemy_id, x, y, hidden = false)
    if enemy = @db_enemies[enemy_id]
      db_c = Battle::SaveData::SystemData.collection
      # @todo 途中から出現する分も処理してしまっている
      # 現状はデータ作成しかしていないので不都合はないが出現していない敵にdiscoverは紛らわしい
      db_c.discover_enemy(enemy_id)
      @enemies << EnemyStatus.new(enemy, x_from_editor_x(x), y_from_editor_y(y), hidden)
    end
  end

  def x_from_editor_x(editor_x)
    # エディタでは幅580の画像の544px分を中央表示しているので
    # 中央寄せで位置を計算した後画面サイズに引き伸ばす
    (290 + (editor_x - 272)) * @screen_width / 580
  end

  def y_from_editor_y(editor_y)
    # エディタでは上14px分を消して表示しているのでその分をずらす
    editor_y + 14
  end

  def pages
    @troop.pages
  end

  # 戦利品を取得する
  def loot(booty)
    db_c = Battle::SaveData::SystemData.collection
    item_rate = Battle::SaveData::GameData.drop_item_double? ? 2 : 1
    @enemies.each do |enemy|
      next unless enemy.dead?
      booty.loot(enemy.enemy)
      booty.loot_items(enemy.enemy, item_rate)
      db_c.defeat_enemy(enemy.enemy.id)
    end
  end

  # --------------------------------------------------
  # 敵情報

  class EnemyStatus
    include SaveData::Game::Actor::Status
    attr_reader :enemy
    alias :battler :enemy
    attr_accessor :x, :y, :hidden
    def enemy_id; @enemy_id || @enemy.id; end

    def initialize(enemy, x, y, hidden = false)
      @enemy = enemy
      @x = x
      @y = y
      @hidden = hidden
      super
    end

    def transform(enemy)
      @enemy_id ||= @enemy.id # 原形のID
      @enemy = enemy
    end

    # @memo 敵と味方で行動追加回数の処理を変えるため
    def additional_move_count; 0; end

    def icon_index; enemy.special_flag(:icon_index) || 9; end
    def name; enemy.name; end
    def param_base(id); enemy.params[id]; end
    def features; super + enemy.features; end
    def actions; enemy.actions; end
  end

end


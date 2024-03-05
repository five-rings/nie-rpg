=begin
  パーティに入りうるキャラクターのパラメータなど
=end
class SaveData::Game::Actors < SaveData::Game::Base
  attr_reader :actors
  
  def initialize
    @actors = {}
  end
  
  def [](actor_id = nil)
    if actor_id
      # 存在しないときだけ追加するのでそのまま呼んでしまう
      add_actor(actor_id)
    else
      @actors
    end
  end
  
  def add_actor(actor_id)
    @actors[actor_id] ||= SaveData::Game::Actor.new(actor_id)
  end
  
  # アクターを初期化する
  # @note インスタンスが変更され装備など全て破棄されるおで注意
  def reset_actor(actor_id)
    @actors[actor_id] = SaveData::Game::Actor.new(actor_id)
  end
  
  def has_actor?(actor_id)
    @actors.has_key?(actor_id)
  end

  def on_save
    @actors.each_value(&:clear_features_cache)
  end

  # パーティ能力は誰か一人でも持っていれば有効
  def encounter_half?; @actors.values.any?(&:encounter_half?); end
  def encounter_none?; @actors.values.any?(&:encounter_none?); end
  def gold_double?; @actors.values.any?(&:gold_double?); end
  def drop_item_double?; @actors.values.any?(&:drop_item_double?); end

end

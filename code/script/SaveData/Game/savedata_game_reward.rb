=begin
  クエスト報酬の受け取り情報
=end
class SaveData::Game::Reward < SaveData::Game::Inventory

  alias :received? :has_item?

  # クエスト報酬受取に使用したアイテムを記録する
  def exchange(item_id)
    @exchanged_tokens ||= Hash.new(0)
    @exchanged_tokens[item_id] += 1
  end

  # 指定したアイテムをクエスト報酬受け取りに使用したか
  def exchanged?(item_id)
    @exchanged_tokens && @exchanged_tokens[item_id] > 0
  end

end


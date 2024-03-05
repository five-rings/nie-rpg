=begin
  販売した大事なもの
=end
class SaveData::Game::Important < SaveData::Game::Inventory
  attr_reader :prices   # 販売時の価格を上書きする用のデータ
  def add_item(item, diff)
    if diff > 0 && (max = item.special_flag(:amount))
      num = Application::Accessor::GameData.number_of_item(item)
      odiff = diff
      diff = Itefu::Utility::Math.min(Itefu::Utility::Math.max(0, max-num), diff)
      return odiff if diff == 0
      super
      odiff - diff
    else
      super
    end
  end

  # 販売時の価格を指定して追加する
  def add_item_with_price(item, price)
    @prices ||= Prices.new(nil)
    @prices[item] = price
    add_item(item, 1)
  end

  # 販売時の価格ごと削除する
  def remove_priced_item(item, count)
    remove_item(item, count)
    # 完売したときに価格の上書き情報を削除する
    @prices && @prices.delete(item) unless has_item?(item)
  end

  def price_overridden(item)
    @prices && @prices[item]
  end

end

class SaveData::Game::Important::Prices <SaveData::Game::Inventory::Items
  def marshal_load(objs)
    super
    self.default = nil
  end
end


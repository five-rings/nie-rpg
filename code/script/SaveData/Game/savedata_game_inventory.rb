=begin
  所持品のデータ  
=end
class SaveData::Game::Inventory < SaveData::Game::Base
  attr_reader :items
  
  def initialize
    @items = Items.new(0)
  end
  
  # @return [Boolean] 指定したアイテムを所持しているか
  def has_item?(item)
    @items.has_key?(item)
  end
  
  def has_item_by_id?(item_id)
    has_item?(item_entry(item_id))
  end
  
  def has_weapon_by_id?(weapon_id)
    has_item?(weapon_entry(weapon_id))
  end
  
  def has_armor_by_id?(armor_id)
    has_item?(armor_entry(armor_id))
  end
  
  # @return [Fixnum] アイテム所持数、未所持なら0
  def number_of_item(item)
    @items[item]
  end
  
  def number_of_item_by_id(item_id)
    number_of_item(item_entry(item_id))
  end
  
  def number_of_weapon_by_id(weapon_id)
    number_of_item(weapon_entry(weapon_id))
  end
  
  def number_of_armor_by_id(armor_id)
    number_of_item(armor_entry(armor_id))
  end
  
  # アイテムを増やす
  # @note countに負の値を与えた場合はremove_itemを呼び出す
  # @return [Fixnum] 追加できなかった数を返す
  def add_item(item, count = 1)
    ITEFU_DEBUG_ASSERT(RPG::BaseItem === item, "inventory: adding unknown item: #{item}")
    if count > 0
      @items[item] += count
      0
    elsif count < 0
      remove_item(item, -count)
    else
      0
    end
  end
  
  def add_item_by_id(item_id, count = 1)
    add_item(item_entry(item_id), count)
  end
  
  def add_weapon_by_id(weapon_id, count = 1)
    add_item(weapon_entry(weapon_id), count)
  end
  
  def add_armor_by_id(armor_id, count = 1)
    add_item(armor_entry(armor_id), count)
  end
  
  # アイテムを減らす
  # @return [Fixnum] 減らし切れなかった個数を負の値で返す
  # @param [Fixnum|NilClass] count 減らす個数, nilを指定すると全て捨てる
  def remove_item(item, count = 1)
    if has_item?(item)
      n = count && (@items[item] -= count) || 0
      if n <= 0
        @items.delete(item)
        n
      else
        0
      end
    else
      ITEFU_DEBUG_OUTPUT_CAUTION "remove_item: no item to remove #{item.kind}-#{item.id} #{count}" if count != 0
      count && -count || 0
    end
  end
  
  # アイテムを持っているだけ減らす
  def remove_all_items(item)
    remove_item(item, nil)
  end
  
  def remove_item_by_id(item_id, count = 1)
    remove_item(item_entry(item_id), count)
  end
  
  def remove_all_items_by_id(item_id)
    remove_item_by_id(item_id, nil)
  end
  
  def remove_weapon_by_id(weapon_id, count = 1)
    remove_item(weapon_entry(weapon_id), count)
  end
  
  def remove_all_weapons_by_id(weapon_id)
    remove_weapon_by_id(weapon_id, nil)
  end
  
  def remove_armor_by_id(armor_id, count = 1)
    remove_item(armor_entry(armor_id), count)
  end
  
  def remove_all_armors_by_id(armor_id)
    remove_armor_by_id(armor_id, nil)
  end

  # アイテムをインベントリの最後尾に配置しなおす
  def replace_item(item, threshold = 0)
    if has_item?(item)
      count = @items[item]
      if count > threshold
        @items.delete(item)
        @items[item] = count
      end
    end
  end

  # idから所持アイテムを探す
  def find_entry_by_id(kind, id)
    @items.each_key.find {|item|
      item.kind == kind &&
      item.id == id
    }
  end
  
  def find_item_by_id(id)
    find_entry_by_id(RPG::Item.kind, id)
  end
  
  def find_weapon_by_id(id)
    find_entry_by_id(RPG::Weapon.kind, id)
  end

  def find_armor_by_id(id)
    find_entry_by_id(RPG::Armor.kind, id)
  end

  def select_entries(kind)
    if block_given?
      @items.each_key.select {|item|
        item.kind == kind && yield(item)
      }
    else
      @items.each_key.select {|item|
        item.kind == kind
      }
    end
  end

  def select_items(&block)
    select_entries(RPG::Item.kind, &block)
  end

  def select_weapons(&block)
    select_entries(RPG::Weapon.kind, &block)
  end

  def select_armors(&block)
    select_entries(RPG::Armor.kind, &block)
  end


private
  def item_entry(item_id)
    Application.database.items[item_id]
  end

  def weapon_entry(weapon_id)
    Application.database.weapons[weapon_id]
  end

  def armor_entry(armor_id)
    Application.database.armors[armor_id]
  end

end

class SaveData::Game::Inventory::Items < Hash
  # セーブ時はアイテムをIDだけで保存する
  def marshal_dump
    Hash[self.map {|k, v|
      [SaveData::Game::ItemData.new(k), v]
    }]
  end

  # アイテムIDで保存されたアイテムを実アイテムに復旧して読み込む
  def marshal_load(objs)
    objs.each_with_object(self) {|(k, v), memo|
      if item = k.resume
        memo[item] = v
      end
    }
    self.default = 0
  end
end

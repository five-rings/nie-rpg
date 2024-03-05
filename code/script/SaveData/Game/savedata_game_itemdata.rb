=begin
  アイテムを保存するときのデータ型
=end
class SaveData::Game::ItemData
  attr_reader :kind     # [Fixnum] アイテムの種類
  attr_reader :id       # [Fixnum] アイテムのID
  attr_reader :options  # [Array] 追加データ

  OptionData = Struct.new(:kind, :id, :count)

  def initialize(entry)
    if entry
      @kind = entry.kind
      @id = entry.id
      if RPG::EquipItem === entry
        extra_items = entry.extra_items
        @options = extra_items.map {|extra_data|
          extra_data && OptionData.new(extra_data.item.kind, extra_data.item.id, extra_data.count)
        } if extra_items
      end
    end
  end

  def resume
    if self.id > 0
      entry = case self.kind
              when RPG::Weapon.kind
                Application.database.weapons[self.id]
              when RPG::Armor.kind
                Application.database.armors[self.id]
              when RPG::Item.kind
                Application.database.items[self.id]
              end
    else
      if item = Application.database.items[id * -1]
        entry = self.class.copy_armor_from_item(item)
      end
    end

    if RPG::EquipItem === entry && @options
     extra_items = entry.extra_items
     if extra_items.nil? || extra_items.empty?
        @options.each.with_index do |option_data, i|
          next unless option_data
          item = case option_data.kind
                 when RPG::Weapon.kind
                   Application.database.weapons[option_data.id]
                 when RPG::Armor.kind
                   Application.database.armors[option_data.id]
                 when RPG::Item.kind
                   Application.database.items[option_data.id]
                 end
          entry.embed_extra_item(i, item, option_data.count) if item
        end
      end
    end

    entry
  end

  # アイテムからダミー装備を作成する
  def self.copy_armor_from_item(item)
    eitem = RPG::Armor.new
    eitem.id = -item.id   # 仮idを与える
    eitem.icon_index = item.icon_index
    eitem.name = item.name
    eitem.description = item.description
    eitem.note = item.note
    eitem.etype_id = nil
    db_items = Application.database.items
    db_items.insert_special_flag(eitem)
    eitem.special_flags[:item_id] = item.id
    eitem
  end

end

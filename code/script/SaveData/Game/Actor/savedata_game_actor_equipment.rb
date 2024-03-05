=begin
  パーティメンバーの装備品
=end
module SaveData::Game::Actor::Equipment
  attr_reader :equipments # [Equipment::Items<Type, RPG::EquipItem>]
  Type = Definition::Game::Equipment::Type
  
  def initialize(*args)
    @equipments = Items[
      Type.constants.map{|type| Type.const_get(type) }.zip([])
    ]
    super
  end
  
  def equip(position, item)
    ITEFU_DEBUG_ASSERT(@equipments.has_key?(position), "#{position} is not a equipable part")
    @equipments[position] = item
  end
  
  def unequip(position)
    equip(position, nil)
  end

  # デフォルト装備枠ではない場合は枠ごと削除する
  def remove_equip(position)
    if Type.constants.find {|type|
      position == Type.const_get(type)
    }
      unequip(position)
    else
      @equipments.delete(position)
    end
  end

  def equipment(position)
    @equipments[position]
  end

  def number_of_equipments(item = nil, &block)
    if item
      @equipments.values.count(item)
    else
      @equipments.values.count(&block)
    end
  end

  # [通常攻撃]のアニメーション（装備上書き）
  def attack_animation_id
    weapon = @equipments[Type::RIGHT_HAND]
    if RPG::Weapon === weapon && weapon.animation_id > 0
      weapon.animation_id
    else
      # 素手
      super
    end
  end

  # 術式を使えるか？
  def equipped_magic?
    equipment(Type::LEFT_HAND).nil?.!
  end

  # 特定のアイテムを装備しているか
  def equipped?(item)
    @equipments.has_value?(item)
  end

end

class SaveData::Game::Actor::Equipment::Items < Hash
  # セーブ時はアイテムをIDだけで保存する
  def marshal_dump
    Hash[self.map {|k, v|
      [k, v && SaveData::Game::ItemData.new(v)]
    }]
  end

  # アイテムIDで保存されたアイテムを実アイテムに復旧して読み込む
  def marshal_load(objs)
    objs.each_with_object(self) {|(k, v), memo|
      memo[k] = v && v.resume
    }
  end
end

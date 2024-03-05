=begin
=end
module Definition::Game
  NUM_OF_LIFE = 3
  MIN_MONEY = 0
  MAX_MONEY = 9999999

  module Save
    QUICK_SAVE_LOAD_INDEX = 1
  end

  module Equipment
    module Type
      RIGHT_HAND = :weapon
      LEFT_HAND = :shield
      HEAD = :head
      BODY = :body
      ACCESSORY_A = :accessory_a
      ACCESSORY_B = :accessory_b
    end
    
    Rgss3 = Itefu::Rgss3::Definition::Equipment

    def self.convert_from_rgss3(slot)
      case slot
      when Rgss3::Slot::WEAPON
        Type::RIGHT_HAND
      when Rgss3::Slot::SHIELD
        Type::LEFT_HAND
      when Rgss3::Slot::HEAD
        Type::HEAD
      when Rgss3::Slot::BODY
        Type::BODY
      when Rgss3::Slot::ACCESSORY
        Type::ACCESSORY_A
      end
    end

    def self.convert_to_rgss3(slot)
      case slot
      when Type::RIGHT_HAND
        Rgss3::Slot::WEAPON
      when Type::LEFT_HAND
        Rgss3::Slot::SHIELD
      when Type::HEAD
        Rgss3::Slot::HEAD
      when Type::BODY
        Rgss3::Slot::BODY
      when Type::ACCESSORY_A,
           Type::ACCESSORY_B
        Rgss3::Slot::ACCESSORY
      end
    end

    module Extra
      DEFAULT_SLOT_OF_WEAPON = 3
      DEFAULT_SLOT_OF_ARMOR  = 3
      DEFAULT_MAX_TO_EMBED_TO_WEAPON = 10
      DEFAULT_MAX_TO_EMBED_TO_ARMOR  = 1
      LIMIT_SLOT_OF_WEAPON = 50
      LIMIT_SLOT_OF_ARMOR = 50
      LIMIT_TO_EMBED_TO_WEAPON = 100
    end
  end
  
  module SpecialClass
=begin
    ADVENTURER = :adventurer
    HUNTER = :hunter
    SMITH = :smith
    ALCHEMIST = :alchemist
=end
  end

  module EndingType
    NONE = nil
    DISCARD_JOURNAL = 1
    GAME_OVER = 2
  end

end

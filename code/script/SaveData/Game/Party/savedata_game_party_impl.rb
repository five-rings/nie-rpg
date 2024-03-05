=begin
=end
class SaveData::Game::Party
  include SaveData::Game::Party::Money
  # include SaveData::Reservoir
  include SaveData::Game::Party::PassiveSkill
  attr_reader :members

  # パーティレベルなど用
  class Level
    include SaveData::Game::Actor::Level
    include SaveData::Game::Party::Money
    alias :point :money
    alias :add_point :add_money
    
    def initialize(party, special_class_symbol)
      @party = party
      classes = Application.database.classes
      special_class = classes.special(special_class_symbol)
      @level_table_id = special_class.id
      super
    end
    
    def initial_level; 1; end
    def max_level; 99; end
    
    def add_level(value = 1)
      old_level = @level
      super.tap do
        add_passive_skill_point(old_level)
      end
    end
    
    def add_passive_skill_point(old_level)
      diff = @level - old_level
      @party.add_passive_skill_point(diff) if diff > 0
    end
  end
  

  def initialize
    super
    @sp_levels = {}
    Application.database.classes.special_classes.each_key do |sp_id|
      @sp_levels[sp_id] = Level.new(self, sp_id)
    end

    system = Application.database.system.rawdata
    @members = system.party_members.clone
  end
  
  def add_member(actor_id)
    return if has_member?(actor_id)
    @members.push(actor_id)
  end
  
  def remove_member(actor_id)
#ifdef :ITEFU_DEVELOP
    @members.delete(actor_id).tap {
      if @members.empty?
        ITEFU_DEBUG_OUTPUT_WARNING "there is no party member"
      end
    }
#else    
    @members.delete(actor_id)
#endif
  end
  
  def members
    @members
  end
  
  def has_member?(actor_id)
    @members.include?(actor_id)
  end

  def member_index(actor_id)
    @members.find_index(actor_id)
  end

  # 冒険者レベル
  def adventurer; @sp_levels[Definition::Game::SpecialClass::ADVENTURER]; end
  # ハンターレベル
  def hunter; @sp_levels[Definition::Game::SpecialClass::HUNTER]; end
  # 鍛冶レベル
  def smith; @sp_levels[Definition::Game::SpecialClass::SMITH]; end
  # 錬金レベル
  def alchemist; @sp_levels[Definition::Game::SpecialClass::ALCHEMIST]; end

  # パーティスキル  
  def skills(sp_id)
    return unless sp_class = Application.database.classes.special(sp_id)
    sp_class.learnings.grep(
      lambda {|learning| learning.level <= @sp_levels[sp_id].level }
    ) {|learning|
      learning.skill_id
    }
  end
  
  # 全パーティスキル
  def all_skills
    Definition::Rpg::SpecialClass.constants.inject([]) do |memo, sp|
      symbol = Definition::Game::SpecialClass.const_get(sp)
      memo + skills(symbol)
    end
  end
  
  # 冒険者スキル
  def adventurer_skills; skills(Definition::Game::SpecialClass::ADVENTURER); end
  # ハンタースキル
  def hunter_skills; skills(Definition::Game::SpecialClass::HUNTER); end
  # 鍛冶スキル
  def smith_skills; skills(Definition::Game::SpecialClass::SMITH); end
  # 錬金スキル
  def alchemist_skills; skills(Definition::Game::SpecialClass::ALCHEMIST); end

end

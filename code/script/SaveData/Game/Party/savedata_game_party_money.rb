=begin
  
=end
module SaveData::Game::Party::Money
  attr_reader :money  # [Fixnum]
  
  def initialize(*args)
    @money = 0
    super
  end
  
  def money_max
    Definition::Game::MAX_MONEY
  end
  
  def money_min
    Definition::Game::MIN_MONEY
  end
  
  def add_money(addition)
    @money = Itefu::Utility::Math.clamp(money_min, money_max, @money+addition)
  end
  
end

=begin
=end
class Battle::Unit::Picture < Game::Unit::Picture
  def default_priority; Battle::Unit::Priority::PICTURE; end
  include Battle::Unit::Base::Implement
end

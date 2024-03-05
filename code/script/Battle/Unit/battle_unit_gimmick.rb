=begin
=end
class Battle::Unit::Gimmick < Battle::Unit::Base
  include Game::Unit::Gimmick
  def default_priority; Battle::Unit::Priority::GIMMICK; end
  def gimmick_klass; Battle::Unit::Gimmick; end

end

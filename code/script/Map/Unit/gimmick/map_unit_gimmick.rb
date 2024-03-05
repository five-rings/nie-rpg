=begin
   画面効果、天候、特殊効果など 
=end
class Map::Unit::Gimmick < Map::Unit::Base
  include Game::Unit::Gimmick
  def default_priority; Map::Unit::Priority::GIMMICK; end
  def gimmick_klass; Map::Unit::Gimmick; end

  def player; @manager.player_unit; end

  def on_suspend
    @gimmicks.each_with_object({}) {|(k,v), m|
      m[k] = [v.class, v.suspend]
    }
  end

  def on_resume(context)
    @gimmicks.each_value(&:finalize)
    @gimmicks.clear
    context.each do |id, v|
      next unless klass = v[0]
      args  = v[1]
      if args
        add_gimmick(id, klass, *args)
      else
        add_gimmick(id, klass)
      end
    end
  end

  def on_update
    return unless state_started?
    super
  end

end

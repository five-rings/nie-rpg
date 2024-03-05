=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::UsableItem

  alias :raw_repeats :repeats
  def repeats
    params = special_flag(:repeat_range)
    if params && (min = params[0]) && (max = params[1])
      Itefu::Utility::Math.rand_in(min, max)
    else
      raw_repeats
    end
  end

end

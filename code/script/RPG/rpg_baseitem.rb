=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::BaseItem
  attr_accessor :name_plural
  attr_accessor :name_unit
  attr_accessor :name_indefinite
  attr_accessor :name_short

  def short_name
    name_short || name
  end

  def numbered_name(num)
    if num == 1
      name
    else
      name_plural || name
    end
  end

  def counter(num)
    if num == 1
      (name_indefinite || "") % num
    else
      unit(num)
    end
  end

  def unit(num)
    (name_unit || Application.language.message(:game, :default_unit) || num.to_s) % num
  end

end


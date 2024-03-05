=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::Item
  def self.kind; :item; end
  def kind; self.class.kind; end
  def sort_index; special_flag(:sort) || id; end

  def <=>(rhs)
    case rhs
    when RPG::Item
      self.sort_index <=> rhs.sort_index
    when RPG::Weapon
      -1
    when RPG::Armor
      -1
    end
  end

  alias :raw_description :description
  def description
    if special_flag(:equip)
      msg = Application.language.message(:game, :description_equip)
      "#{raw_description}\n#{msg}"
    else
      raw_description
    end
  end

end

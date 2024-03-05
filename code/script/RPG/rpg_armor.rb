=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::Armor
  def self.kind; :armor; end
  def kind; self.class.kind; end
  def sort_index; special_flag(:sort) || id; end

  def <=>(rhs)
    case rhs
    when RPG::Item
      1
    when RPG::Weapon
      1
    when RPG::Armor
      self.sort_index <=> rhs.sort_index
    end
  end

  def type_id; atype_id; end

end

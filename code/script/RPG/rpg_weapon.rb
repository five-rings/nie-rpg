=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::Weapon
  def self.kind; :weapon; end
  def kind; self.class.kind; end
  def sort_index; special_flag(:sort) || id; end

  def <=>(rhs)
    case rhs
    when RPG::Item
      1
    when RPG::Weapon
      self.sort_index <=> rhs.sort_index
    when RPG::Armor
      -1
    end
  end

  def type_id; wtype_id; end

end

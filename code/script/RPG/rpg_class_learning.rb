=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::Class::Learning

  # include?での比較用
  def ==(rhs)
    return false unless self.class === rhs
    return false if self.level != rhs.level
    return false if self.skill_id != rhs.skill_id
    true
  end

end


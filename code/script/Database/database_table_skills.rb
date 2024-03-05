=begin
=end
class Database::Table::Skills < Database::Table::BaseItem

  def replace_text
    replace_db_text("skill_name_", :name=)
    replace_db_text("skill_short_", :name_short=)
    replace_db_text("skill_description_", :description=)
    replace_db_text("skill_unit_", :name_unit=)
    replace_db_text("skill_plural_", :name_plural=)
    replace_db_text("skill_indefinite_", :name_indefinite=)
  end

private

  def convert_special_flag(command, param)
    case command
    when :chain
      param.split(",").map! {|p| Integer(p) rescue 0 }
    when :speed_damage
      Integer(param) rescue nil
    when :restriction
      param.split(",")
    when :medium
      param.split(",").map! {|p| Integer(p) rescue nil }
    when :sort
      Float(param) rescue nil
    when :stroke_max
      Integer(param) rescue nil
    when :repeat_range
      param.split(",").map {|v| Integer(v) rescue nil }
    else
      super
    end
  end

end

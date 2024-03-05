=begin
=end
class Database::Table::Items < Database::Table::BaseItem
  def type; :item; end

  def replace_text
    replace_db_text("#{type}_name_", :name=)
    replace_db_text("#{type}_short_", :name_short=)
    replace_db_text("#{type}_description_", :description=)
    replace_db_text("#{type}_unit_", :name_unit=)
    replace_db_text("#{type}_plural_", :name_plural=)
    replace_db_text("#{type}_indefinite_", :name_indefinite=)
  end

  def insert_special_flag(entry)
    @temp_entry = entry
    super
    @temp_entry = nil
  end

private
  def convert_special_flag(command, param)
    case command
    when :material
      Integer(param) rescue 0
    when :amount
      Integer(param) rescue nil
    when :sort
      Float(param) rescue nil
    when :auto_state, :auto_skill
      ret = @temp_entry.special_flag(command) || []
      ps = param.split(",")
      ret << { turn: Integer(ps[0]), id: Integer(ps[1]) }
      ret
    when :exp
      Integer(param) rescue nil
    when :speed_damage
      Integer(param) rescue nil
    when :equip
      param.intern
    when :stroke_max
      Integer(param) rescue nil
    when :repeat_range
      param.split(",").map {|v| Integer(v) rescue nil }
    else
      super
    end
  end

end

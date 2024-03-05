=begin
=end
class Database::Table::Classes < Database::Table::BaseItem
  attr_reader :special_classes

  def special(special_id)
    @special_classes[special_id]
  end

  def replace_text
    replace_db_text("class_name_", :name=)
    i = 0
    begin
      ret = replace_db_text("class_highname#{i}_", :job_name=)
      i += 1
    end while ret
  end

  def insert_special_flag(entry)
    @temp_entry = entry
    super
    @temp_entry = nil
  end

private

  def convert_special_flag(command, param)
    case command
    when :job_name
      ret = @temp_entry.special_flag(command) || {}
      ps = param.split(",")
      ret[Integer(ps[0])] = ps[1]
      ret
    when :delete_skill
      ret = @temp_entry.special_flag(command) || {}
      key, sid = param.split(",").map {|p| Integer(p) }
      ret[key] ||= []
      ret[key] << sid
      ret
    else
      super
    end
  end

  def on_special_flag_set(filename)
    @special_classes = {}
    Definition::Game::SpecialClass.constants.each do |const_id|
      special_id = Definition::Game::SpecialClass.const_get(const_id)
      @special_classes[special_id] = find_special_class(special_id)
    end
  end

  def find_special_class(special_id)
    @rawdata.find {|entry|
      entry && entry.special_flags[special_id]
    }
  end

end

=begin
=end
class Database::Table::Actors < Database::Table::BaseItem

  def replace_text
    replace_db_text("actor_name_", :name=)
  end

private

  def convert_special_flag(command, param)
    case command
    when :icon_index
      Integer(param) rescue nil
    else
      super
    end
  end

end

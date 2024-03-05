=begin
=end
class Database::Table::System < Itefu::Database::Table::System
  include Database::Table::Language

  def replace_text
    replace_db_text("system_element_", :replace, @rawdata.elements)
    replace_db_text("system_skill_", :replace, @rawdata.skill_types)
    replace_db_text("system_weapon_", :replace, @rawdata.weapon_types)
    replace_db_text("system_armor_", :replace, @rawdata.armor_types)
  end

private

  def on_loaded(filename)
    super
    replace_text
  end

end

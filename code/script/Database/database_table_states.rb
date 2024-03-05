=begin
=end
class Database::Table::States < Database::Table::BaseItem

  def replace_text
    replace_db_text("state_name_", :name=)
    replace_db_text("state_message3_", :message3=)
    replace_db_text("state_message4_", :message4=)
    replace_db_text("state_label_", :label=)
    replace_db_text("state_detail", :detail=)
  end

end

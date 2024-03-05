=begin
=end
class Database::Table::BaseItem < Itefu::Database::Table::BaseItem
  include Database::Table::Language

  def load(filename)
    ret = super
    replace_text
    ret
  end

end


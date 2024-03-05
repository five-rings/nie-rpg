=begin
  Rgss3のデフォルト実装を拡張する
=end
class RPG::Skill
  def use_all_mp?; special_flag(:use_all_mp); end
  def restriction_keys; special_flag(:restriction); end
  def secret_name?; special_flag(:secret); end
  def medium_id; (m = special_flag(:medium)) && m[0]; end
  def medium_num; (m = special_flag(:medium)) && m[1] || 1; end
  def sort_index; special_flag(:sort) || id; end

  def <=>(rhs)
    case rhs
    when RPG::Skill
      self.sort_index <=> rhs.sort_index
    end
  end


  alias :raw_description :description
  def description
    if (m = medium_id) && (medium_item = Application.database.items[m])
        num = medium_num
        msg = Application.language.message(:game, :description_medium)
        raw_description + "\n" + format(msg, item: medium_item.name, count: num)
    else
      raw_description
    end
  end

end

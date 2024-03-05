=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::State
  def basic_state?; special_flag(:basic); end
  def notable_state?; special_flag(:notable); end
  def party_state?; special_flag(:party); end
  def exclusive?; exclude_key.nil?.!; end
  def exclude_key; special_flag(:exclude_key); end
  def shortname; special_flag(:shortname) || self.name[0]; end
  def patient?; special_flag(:release) == "hp1"; end

  def label; special_flag(:label); end
  def label=(value)
    special_flags[:label] = value
  end
  def label_name; label || name; end

  def detail; special_flag(:detail); end
  def detail=(value)
    special_flags[:detail] = value
  end
  def detail_name; detail || label || name; end
end

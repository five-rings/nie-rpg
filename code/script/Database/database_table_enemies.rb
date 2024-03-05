=begin
=end
class Database::Table::Enemies < Database::Table::BaseItem

private

  def on_special_flag_set(filename)
    @rawdata.each do |entry|
      entry && entry.setup_gimmick
    end
  end

  def convert_special_flag(command, param)
    case command
    when :icon_index
      Integer(param) rescue nil
    when :scale
      Float(param) rescue 1
    when :chiritori_variable
      Integer(param) rescue nil
    when :known
      case param
      when String
        Integer(param) rescue nil
      else
        super
      end
    else
      super
    end
  end

end


=begin
  Fontの拡張
=end
class Font
  alias :size_org= :size=
  def size=(value)
    self.size_org = value
  rescue ArgumentError
    ITEFU_DEBUG_OUTPUT_WARNING "Font: invalid size #{value}"
    self.size_org = Itefu::Utility::Math.clamp(6, 96, value)
  end
end


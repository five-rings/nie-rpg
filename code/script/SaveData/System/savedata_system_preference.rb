=begin
  各種設定
=end
class SaveData::System::Preference
  attr_accessor :locale
  attr_accessor :volumes

  VOLUME_MAP = [:bgm, :me, :bgs, :se].freeze

  def initialize
    self.locale = nil
    self.volumes = Hash[VOLUME_MAP.map {|key| [key, 90] }]
  end

end

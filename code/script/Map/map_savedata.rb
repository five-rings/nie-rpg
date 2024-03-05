=begin
  セーブデータにアクセスするインターフェイス
=end
module Map::SaveData
  extend Application::Accessor::Flags
  module GameData
    extend Application::Accessor::GameData
  end
end

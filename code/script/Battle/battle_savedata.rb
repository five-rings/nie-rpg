=begin
  セーブデータにアクセスするインターフェイス
=end
module Battle::SaveData
  extend Application::Accessor::Flags
  module GameData
    extend Application::Accessor::GameData
  end
  module SystemData
    extend Application::Accessor::SystemData
  end
end

=begin
  マップ関連の進行データの共通クラス
=end
class SaveData::Game::Base
  
  # ロードした後に呼ばれる
  def on_load
  end

  # セーブする前に呼ばれる
  def on_save(*args)
  end
  
  # 継承時に自動的にSaveData::Gameに追加する
  def self.inherited(derived)
    name = Itefu::Utility::String.remove_namespace(derived.name)
    id = Itefu::Utility::String.snake_case(name).intern
    unless SaveData::Game.method_defined?(id)
      SaveData::Game.add_data_klass(id, derived)
      SaveData::Game.define_accessor(id)
    end
  end
  
end

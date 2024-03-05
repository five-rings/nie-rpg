=begin
  システムデータ
=end
class SaveData::System < Itefu::SaveData::Base
  VERSION = 4
  attr_reader :version      # データのバージョン
  attr_reader :input        # キーコンフィグ
  attr_reader :collection   # 敵情報など
  attr_reader :offering     # 引継ぎ用の一時データ
  attr_reader :flags        # ゲーム共通のフラグ
  attr_reader :preference   # ゲーム設定

private

  def on_new_data
    @version = VERSION
    @input = SaveData::System::Input.new
    @collection = SaveData::System::Collection.new
    @offering = SaveData::Game::Inventory.new
    @flags = {}
    @preference = SaveData::System::Preference.new
    true
  end

  def on_load(io, name)
    @version = inflate_load(io)

    # input
    case @version
    when 1
      inflate_load(io)
      @input = SaveData::System::Input.new
    else
      @input = inflate_load(io)
    end

    # collection
    @collection = inflate_load(io)

    # offering
    if @version <= 3
      @offering = inflate_load(io)
      @offering.on_load
    else
      @offering = SaveData::Game::Inventory.new
    end

    # flags
    @flags = inflate_load(io)

    # preference
    case @version
    when 1
      @preference = SaveData::System::Preference.new
    when 2
      @preference = SaveData::System::Preference.new
      @preference.locale = inflate_load(io)
    else
      @preference = inflate_load(io)
    end

    # 対応済みの古いバージョン
    case @version
    when 1, 2, 3
      @version = VERSION
    end

    VERSION == @version
  end
  
  def on_save(io, name)
    @offering.on_save
    deflate_dump(@version, io)
    deflate_dump(@input, io)
    deflate_dump(@collection, io)
    if @version <= 3
      # 一時データなので保存しない
      deflate_dump(@offering, io)
    end
    deflate_dump(@flags, io)
    deflate_dump(@preference, io)
    true
  end

end

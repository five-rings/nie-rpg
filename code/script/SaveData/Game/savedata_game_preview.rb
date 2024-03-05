=begin
  ゲームの進行データのヘッダ情報を確認するためのクラス
=end
class SaveData::Game::Preview < Itefu::SaveData::Base
  attr_reader :version
  attr_reader :header
  attr_accessor :save_slot  # [Fixnum] 画像データとの関連付けに利用する

private
  
  def on_new_data
    raise Itefu::Exception::NotSupported
  end

  def on_save(io, name)
    raise Itefu::Exception::NotSupported
  end
  
  def on_load(io, name)
    @version = inflate_load(io)
    if SaveData::Game::VERSION >= @version
      @header  = inflate_load(io)
      @header.on_load
      true
    end
  end

end

=begin
  ゲームの進行データ
=end
class SaveData::Game < Itefu::SaveData::Base
  VERSION = 2
  attr_reader :version
  attr_reader :header
  attr_reader :data
  # @note @dataへのアクセッサはSaveData::Game::Baseを継承すると自動定義される
  ITEM_ID_JOURNAL = 1  # 追思帳のID
  
  # データに含めるクラスを追加する
  def self.add_data_klass(id, klass)
    @@data[id] = klass
  end
  
  # アクセッサを定義する
  def self.define_accessor(id)
    define_method(id) do
      @data[id]
    end
  end
  
  # 今のセーブデータでタイトル画面からやり直す際に呼ぶ
  def reset_for_restart
    self.system.reset
    self.map.reset_resuming_context
    self.map.reset_to_start_position
    # 追思帳を手放す
    self.inventory.remove_all_items_by_id(ITEM_ID_JOURNAL)
  end
  
#ifdef :ITEFU_DEVELOP
  # デバッグプレイ時に必要なフラグを設定する
  def reset_for_debug_play
    self.system.reset_for_debug_play
    # 追思帳を追加
    self.inventory.add_item_by_id(ITEM_ID_JOURNAL) unless self.inventory.has_item_by_id?(ITEM_ID_JOURNAL)
  end
#endif

private
  @@data = {}
  
  def on_new_data
    @version = VERSION
    @header  = SaveData::Game::Header.new
    @data    = {}
    # 自動的に収集されたセーブデータ型を組み込む
    # headerなど自前でアクセッサを用意しているものは除外されている
    @@data.each do |id, klass|
      @data[id] = klass.new
    end
    true
  end
  
  def on_load(io, name)
    @version = inflate_load(io)
    if VERSION >= @version
      @header  = inflate_load(io)
      @data    = inflate_load(io)
      if VERSION > @version
        # 古いバージョンにはなかったデータを作成する
        @@data.each do |id, klass|
          @data[id] = klass.new unless @data.has_key?(id)
        end
      end
      @header.on_load
      @data.each_value(&:on_load)
      true
    end
  end
  
  def on_save(io, name)
    @header.on_save(@data)
    @data.each_value(&:on_save)
    deflate_dump(@version, io)
    deflate_dump(@header,  io)
    deflate_dump(@data,    io)
    true
  end

end

=begin  
=end
class Map::Manager::State

  # 初回に一度だけ実行される
  module Initialize
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end
  
  # マップインスタンスの生成を待つ
  module WaitForInstance
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # マップ移動時の暗転を解消する
  module ResolveTransfering
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # メイン処理
  module Main
    extend Itefu::Utility::State::Callback::Simple
    define_callback :update
  end
  
  # マップ移動
  module Transfer
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update
  end

  # 終了
  module Quit
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

end

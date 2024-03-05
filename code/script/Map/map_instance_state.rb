=begin  
=end
module Map::Instance::State

  # 初回に一度だけ実行される
  module Initialize
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

  # マップを読み込む際の処理
  # @note マップ移動などで違うマップを読み直すことがあり得る
  module Setup
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

  # 暗転などを開く
  module Open
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 開始待ち
  module WaitToStart
    extend Itefu::Utility::State::Callback::Simple
    # 外部から遷移されるのを待つだけなので何も実装しない
  end

  # マップ中の処理
  module Main
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :detach, :update, :draw
  end

  # 終了
  module Quit
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

end
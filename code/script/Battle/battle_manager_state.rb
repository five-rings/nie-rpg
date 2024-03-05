=begin  
=end
class Battle::Manager::State

  # 初回に一度だけ実行される
  module Initialize
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :detach
  end

  # 開始演出
  module Opening
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 行動選択
  module Command
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # イベント実行
  module Event
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 行動準備
  module Prepare
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

  # 行動実行
  module Action
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # ターン終了時の追加処理
  module TurnEnd
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

  # ターン中のすべての行動後の処理
  module PostTurn
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 勝利演出
  module Winning
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end
  module Winning2
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 戦闘結果の表示
  module Result
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 敗北演出
  module Losing
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 逃走演出
  module Escaping
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach, :update, :detach
  end

  # 戦闘終了
  module Quit
    extend Itefu::Utility::State::Callback::Simple
    define_callback :attach
  end

end

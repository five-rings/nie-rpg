=begin
  Battle画面で使用するユニット
=end
module Battle::Unit
  module Priority
    Itefu::Utility::Module.declare_enumration(self, [
      :FIELD,
      :INTERPRETER,
      :PICTURE,
      :STATUS,
      :ACTION,
      :COMMAND,
      :PARTY,
      :TROOP,
      :VOICE,
      :DAMAGE,
      :GIMMICK,
      :MESSAGE,
      :RESULT,
    ])
  end

  module State
    INITIALIZED = :initialized  # 初期状態
    FINALIZED   = :finalized    # 終了処理済み
    OPENED      = :opened       # 開始演出が終了した
    STARTED     = :started      # ゲーム開始済み
    COMMANDING  = :commanding   # コマンド入力中
    COMMANDED   = :commanded    # コマンド決定済み
    IN_ACTION   = :action       # アクション実行中
    TURN_END    = :turn_end     # ターン終了
    FINISHING   = :finish       # 終了演出
    QUIT        = :quit         # 戦闘終了
  end
end


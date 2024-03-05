=begin
=end
module Map::Unit
  module Priority
    Itefu::Utility::Module.declare_enumration(self, [
      :SYSTEM,
      :UI,     
      :PICTURE,
      :INTERPRETER,
      :GIMMICK,
      :SCROLL,
      :TILEMAP,
      :PARALLAX,
      :POINTER,
      :EVENTS,
      :PLAYER,
      :SOUND,
    ])
  end

  module State
    INITIALIZED = :initialized  # 初期状態
    FINALIZED   = :finalized    # 終了処理済み
    STARTED     = :started      # マップやユニットの生成が完了
    OPENED      = :opened       # STARTEDかつフェードが解けた
    STOPPED     = :stopped      # マップ変更のため一時停止
  end
end

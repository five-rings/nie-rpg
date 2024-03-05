=begin
=end
module Layout::Constant

  module Font
    MESSAGE_SIZE = 22
    MESSAGE_WORD_SPACE = -3
  end

  module Animation
    # ウィンドウを開く
    OPEN_WINDOW = proc {
      # opennessは1でもウィンドウが結構開いてしまうので最初のフレームでは見えないようにしておく
      add_key  0, :openness, 0, step
      # 通常の開閉
      add_key  1, :openness, 0
      add_key 11, :openness, 0xff
    }
    # ウィンドウを閉じる
    CLOSE_WINDOW = proc {
      add_key  0, :openness, 0xff
      add_key 10, :openness, 0
    }
    # ウィンドウをフェードイン
    APPEAR_WINDOW = proc {
      add_key  0, :opacity, 0
      add_key 10, :opacity, 0xff
    }
    # ウィンドウをフェードアウト
    DISAPPEAR_WINDOW = proc {
      add_key  0, :opacity, 0xff
      add_key 10, :opacity, 0
    }
  end

  module Proc
    ADD_COMMA = proc {|v|
      v && Itefu::Utility::String.number_with_comma(v)
    }
    ADD_COMMA_WITHOUT_0 = proc {|v|
      v == 0 ? "" : v && Itefu::Utility::String.number_with_comma(v)
    }
  end

  module Utility
    def self.turn_count_label(count, default = nil)
      if count && count > 0 && count != Float::INFINITY
        count
      else
        default
      end
    end
  end

  module Z
    module Message
      CHOICES = 0x10
      SHOP    = 0x20
      NUMERIC = 0x30
      BUDGET  = 0x40
    end
  end

end

# 定義ファイルからアクセスしやすいようにする
module Itefu::Layout::Control::DSL
  Constant = Layout::Constant
end

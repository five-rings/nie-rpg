=begin
=end
module Input
  
  DECIDE = :decide
  CLICK = :click
  CANCEL = :cancel
  OPTION = :option
  UP = :up
  DOWN = :down
  LEFT = :left
  RIGHT = :right
  SNEAK = :sneak
  DASH = :dash
  QUICK_SAVE = :quick_save
  QUICK_LOAD = :quick_load
  CONFIG = :config

#ifdef :ITEFU_DEVELOP
  module Debug
    TOGGLE_DRAW = :debug_draw
    SAVE_CAPTURE = :debug_capture
  end
#endif
  
  # RGSS3デフォルトのキーコードとの対応付け
  def self.code_to_mean(code)
    case code
    when DOWN, Itefu::Rgss3::Input::Code::DOWN
      Input::DOWN
    when LEFT, Itefu::Rgss3::Input::Code::LEFT
      Input::LEFT
    when RIGHT, Itefu::Rgss3::Input::Code::RIGHT
      Input::RIGHT
    when UP, Itefu::Rgss3::Input::Code::UP
      Input::UP
    when A, Itefu::Rgss3::Input::Code::A
      Input::DECIDE
    when B, Itefu::Rgss3::Input::Code::B
      Input::CANCEL
    when C, Itefu::Rgss3::Input::Code::C
    when X, Itefu::Rgss3::Input::Code::X
    when Y, Itefu::Rgss3::Input::Code::Y
    when Z, Itefu::Rgss3::Input::Code::Z
    when L, Itefu::Rgss3::Input::Code::L
    when R, Itefu::Rgss3::Input::Code::R
    else
      code
    end
  end

end


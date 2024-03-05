=begin
  キーコンフィグ画面から編集されるデータ
=end
class SaveData::System::Input
  attr_reader :win32, :joypad

  def initialize
    @win32 = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32).instance_eval do
      define(Input::DECIDE, Itefu::Input::Win32::Code::VK_RETURN)
      define(Input::DECIDE, Itefu::Input::Win32::Code::VK_E)
      define(Input::DECIDE, Itefu::Input::Win32::Code::VK_SPACE)
      define(Input::CLICK,  Itefu::Input::Win32::Code::VK_LBUTTON)
      define(Input::CANCEL, Itefu::Input::Win32::Code::VK_ESCAPE)
      define(Input::CANCEL, Itefu::Input::Win32::Code::VK_BACK)
      define(Input::CANCEL, Itefu::Input::Win32::Code::VK_RBUTTON)
      define(Input::CANCEL, Itefu::Input::Win32::Code::VK_Q)
      define(Input::OPTION, Itefu::Input::Win32::Code::VK_F1)
      define(Input::SNEAK,  Itefu::Input::Win32::Code::VK_CONTROL)
      define(Input::DASH,   Itefu::Input::Win32::Code::VK_SHIFT)
      define(Input::QUICK_SAVE,   Itefu::Input::Win32::Code::VK_1)
      define(Input::QUICK_LOAD,   Itefu::Input::Win32::Code::VK_5)
      define(Input::CONFIG,   Itefu::Input::Win32::Code::VK_F3)
      define(Input::UP,     Itefu::Input::Win32::Code::VK_UP)
      define(Input::DOWN,   Itefu::Input::Win32::Code::VK_DOWN)
      define(Input::LEFT,   Itefu::Input::Win32::Code::VK_LEFT)
      define(Input::RIGHT,  Itefu::Input::Win32::Code::VK_RIGHT)
      define(Input::UP,     Itefu::Input::Win32::Code::VK_W)
      define(Input::DOWN,   Itefu::Input::Win32::Code::VK_S)
      define(Input::LEFT,   Itefu::Input::Win32::Code::VK_A)
      define(Input::RIGHT,  Itefu::Input::Win32::Code::VK_D)
      self
    end

    @joypad = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32::JoyPad, 0).instance_eval do
      define(Input::UP,     Itefu::Input::Win32::JoyPad::Code::POS_UP)
      define(Input::UP,     Itefu::Input::Win32::JoyPad::Code::POV_UP)
      define(Input::DOWN,   Itefu::Input::Win32::JoyPad::Code::POS_DOWN)
      define(Input::DOWN,   Itefu::Input::Win32::JoyPad::Code::POV_DOWN)
      define(Input::LEFT,   Itefu::Input::Win32::JoyPad::Code::POS_LEFT)
      define(Input::LEFT,   Itefu::Input::Win32::JoyPad::Code::POV_LEFT)
      define(Input::RIGHT,  Itefu::Input::Win32::JoyPad::Code::POS_RIGHT)
      define(Input::RIGHT,  Itefu::Input::Win32::JoyPad::Code::POV_RIGHT)
      define(Input::DECIDE, Itefu::Input::Win32::JoyPad::Code::BUTTON0)
      define(Input::CANCEL, Itefu::Input::Win32::JoyPad::Code::BUTTON1)
      define(Input::DASH, Itefu::Input::Win32::JoyPad::Code::BUTTON3)
      define(Input::SNEAK, Itefu::Input::Win32::JoyPad::Code::BUTTON4)
      self
    end
  end

end

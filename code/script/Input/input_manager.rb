=begin  
=end
class Input::Manager < Itefu::Input::Manager
  def self.klass_id; Itefu::Input::Manager; end

  # ジョイパッドが使用可能になっていないかチェックする
  def check_joypad
    @statuses.each do |args, status|
      if args[0] == Itefu::Input::Status::Win32::JoyPad 
        status.restart_polling
      end
    end
  end

end

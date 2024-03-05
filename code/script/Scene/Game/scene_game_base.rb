=begin
  どの画面でも共通して書くような処理
=end
class Scene::Game::Base < Itefu::Scene::Base
  include Itefu::Utility::State::Context
  attr_reader :exit_code
  
  # @return [Fixnum] フェードにかける時間(フレーム数)
  def fading_time; 10; end
  
  # フェードイン/アウトしんていないときに呼ばれるupdate
  def on_update_main; end
  # フェードイン/アウトしんていないときに呼ばれるdraw
  def on_draw_main; end
  
  # フェードインが終わって画面の処理を開始する際に一度呼ばれる
  def on_enter_main; end
  # 画面を抜けてフェードアウトを開始する前に一度だけ呼ばれる
  def on_exit_main; end


  # フェードアウトしているならフェードインし終わるまで待つ
  def enter
    change_state(State::Enter)
  end
  
  # フェードアウトし終わったら退出する
  def exit(exit_code = nil)
    @exit_code = exit_code if exit_code
    change_state(State::Exit)
  end
  
  def finalize
    clear_state
    super
  end
  
  def update
    super
    update_state
  end
  
  def draw
    super
    draw_state
  end
  
  module State
    module Enter
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module Exit
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end
    module Main
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :draw, :detach
    end
  end
  
  def on_state_enter_attach
    fade = Application.fade
    fade.resolve if fade.faded_out?
  end
  
  def on_state_enter_update
    fade = Application.fade
    change_state(State::Main) if fade.faded_out?.! && fade.fading?.!
  end
  
  def on_state_main_attach
    on_enter_main
  end
  
  def on_state_main_update
    on_update_main if alive?
  end
  
  def on_state_main_draw
    on_draw_main if alive?
  end
  
  def on_state_main_detach
    on_exit_main
  end
  
  def on_state_exit_attach
    fade = Application.fade
    fade.fade_color(Itefu::Color.Black, fading_time) unless fade.faded_out?
  end
  
  def on_state_exit_update
    fade = Application.fade
    clear_state if fade.faded_out? && fade.fading?.!
  end
  
  def on_state_exit_detach
    quit
  end

end

=begin
  画面遷移をまたいで再生するワンショットアニメーションを登録して使うことを想定している
=end
class Animation::Manager < Itefu::System::Base
  include Itefu::Animation::Player
  attr_reader :viewport
  
  def on_initialize
    @viewport = Itefu::Rgss3::Viewport.new
    @viewport.z = Viewport::Display::ANIME
  end

  def on_finalize
    finalize_animations
    @viewport = @viewport.swap(nil)
  end
  
  def on_update
    update_animations
  end
  
  def decide(target_sprite)
    target_sprite.viewport = @viewport
    a = Animation::Decide.new(target_sprite)
    play_animation(a, a)
  end

end

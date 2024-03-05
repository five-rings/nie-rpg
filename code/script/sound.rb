=begin
  SEコール一覧  
=end
module Sound
class << self
  
  def play_menu_se
    play_decide_se
  end
  
  def play_select_se
    Itefu::Sound.play_cursor_se
  end
  
  def play_decide_se
    Itefu::Sound.play_ok_se
  end
  
  def play_cancel_se
    Itefu::Sound.play_cancel_se
  end
  
  def play_disabled_se
    Itefu::Sound.play_buzzer_se
  end

  def play_paging_se
    Itefu::Sound.play_se("Book1", 80, 120)
  end
  
end
end

module Itefu::Sound
class << self

  def play_critical_se
    play_enemy_damage_se
    play_enemy_attack_se
  end

  def play_weakpoint_se
    play_enemy_damage_se
  end

  def play_resisted_se
    play_actor_collapse_se
  end

  def play_state_resisted_se
    play_miss_se
  end

  def play_normal_damage_se
    play_actor_damage_se
  end

end
end

module Sound::Map; end

# マップで使用する距離減衰計算方法
module Sound::Map::Attenuator
  
  # 楕円形風の距離減衰
  class SimpleEllipse
    def initialize(near, far, min = 0.0, xrate = 1.0, step = 1)
      @near = near ** 2
      @far = far ** 2
      @min = min
      @xrate = xrate
      @step = step.to_i
    end

    def [](volume, x, y)
      (volume * Itefu::Utility::Math.clamp(
        @min, 1.0,
        (@far - (x * @xrate) ** 2 - y**2) / (@far - @near)
      )).to_i / @step * @step
    end
  end
end

=begin
  ブートシーケンス
=end
class Scene::Game::Boot < Itefu::Scene::Base

  def on_initialize(skip_boot = false)
    if skip_boot
#ifdef :ITEFU_DEVELOP
      push_scene(Itefu::Scene::Wait, 3)
#else
      quit
#endif
    else
      push_scene(Scene::Game::Boot::Logo)
    end
  end

  def on_resume(prev_scene)
    quit
  end

end
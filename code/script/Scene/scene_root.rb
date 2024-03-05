=begin
  ゲーム開始時に実行される最初のシーン
=end
class Scene::Root < Itefu::Scene::Base

  def on_initialize
#ifdef :ITEFU_DEVELOP
    case
    when $BTEST
      push_scene(Scene::Debug::Battle)
      # push_scene(Scene::Debug::Menu::SkillAnimation, 37)
    when $TEST
      push_scene(Scene::Debug::Root)
    else
      push_scene(Scene::Game)
    end
#else
    push_scene(Scene::Game)
#endif
  end
  
  def on_resume(prev_scene)
    quit
  end

end

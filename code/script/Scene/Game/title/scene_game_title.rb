=begin
  タイトル画面
=end
class Scene::Game::Title < Itefu::Scene::Base
  def on_initialize
    # if Application.savedata_game.flags.ending_type != 0
    #   push_scene(Scene::Game::Title::End)
    # else
      push_scene(Scene::Game::Title::Map)
    # end
  end

  def on_resume(prev_scene)
    case prev_scene
    when Scene::Game::Title::Map
      case prev_scene.exit_code
      when Scene::Game::Map::ExitCode::OPEN_SAVE
        push_scene(Scene::Game::Title::Load, prev_scene.exit_param)
      when Scene::Game::Map::ExitCode::OPEN_MENU
        push_scene(Scene::Game::Menu)
      when Scene::Game::Map::ExitCode::OPEN_HELP
        push_scene(Scene::Game::Help)
      when Scene::Game::Map::ExitCode::OPEN_PREFERENCE
        push_scene(Scene::Game::Preference)
      when Scene::Game::Map::ExitCode::NEW_GAME
        push_scene(Scene::Game::Title::Logo)
      when Scene::Game::Map::ExitCode::LOAD
        quit
      else
        push_scene(Scene::Game::Title::Map)
      end
    when Scene::Game::Help, Scene::Game::Menu
      push_scene(Scene::Game::Title::Map)
    when Scene::Game::Preference
      case prev_scene.exit_code
      when :reset
        raise RGSSReset
      when :shutdown
#ifdef :ITEFU_DEVELOP
        raise RGSSReset
#else
        quit
#endif
      else
        push_scene(Scene::Game::Title::Map)
      end
    when Scene::Game::Title::Load
      if Application.savedata_game.system.embodied
        push_scene(Scene::Game::Title::Logo)
      else
        push_scene(Scene::Game::Title::Map)
      end
    when Scene::Game::Title::End
      push_scene(Scene::Game::Title::Map)
    else
      quit
    end
  end
end

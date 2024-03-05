=begin  
  ゲーム本編
=end
class Scene::Game < Itefu::Scene::Base
  @@first_boot = true

  def on_initialize(skip_boot = nil)
    if skip_boot.nil?
      skip_boot = @@first_boot.!
      @@first_boot = false
    end
    push_scene(Scene::Game::Boot, skip_boot)
  end

  def on_finalize
    if @message
      Application.language.release_message(:menu)
    end
  end

  def menu_message
    @message ||= Application.language.load_message(:menu)
  end
  
  def on_resume(prev_scene)
    case prev_scene
    when Scene::Game::Boot
      if Application.savedata_game.system.embodied
        push_scene(Scene::Game::Map)
      else
        # 初回のみ
        push_scene(Scene::Game::Title)
      end
    when Scene::Game::Title
      if Application.savedata_game.system.embodied
        push_scene(Scene::Game::Map)
      else
        quit
      end
    when Scene::Game::Map
      case prev_scene.exit_code
      when Scene::Game::Map::ExitCode::OPEN_MENU
        push_scene(Scene::Game::Menu)
      when Scene::Game::Map::ExitCode::OPEN_SYNTH
        push_scene(Scene::Game::Menu, :synth)
      when Scene::Game::Map::ExitCode::OPEN_HELP
        push_scene(Scene::Game::Help)
      when Scene::Game::Map::ExitCode::OPEN_PREFERENCE
        push_scene(Scene::Game::Preference)
      when Scene::Game::Map::ExitCode::OPEN_SAVE
        # タイトル以外からセーブ画面には行かないのでとりあえずマップに戻る
        push_scene(Scene::Game::Map)
      when Scene::Game::Map::ExitCode::SELECT_ITEM
        push_scene(Scene::Game::Menu::ItemSelect, menu_message)
      when Scene::Game::Map::ExitCode::OPEN_OVERVIEW
        # 現在のmap idを渡す
        push_scene(Scene::Game::OverView)
      when Scene::Game::Map::ExitCode::START_BATTLE
        param = prev_scene.exit_param
        push_scene(Scene::Game::Battle,
          param[:troop_id],
          param[:escape],
          param[:lose],
          param[:floor_name],
          param[:wall_name],
          param[:event?],
          param[:gimmick]
        )
      when Scene::Game::Map::ExitCode::LOAD
        push_scene(Scene::Game::Map, prev_scene.exit_code)
      when Scene::Game::Map::ExitCode::NEW_GAME
        push_scene(Scene::Game::Title)
      else
        if Application.savedata_game.system.embodied ||
            prev_scene.exit_param == :quit
          quit
        else
          push_scene(Scene::Game::Title)
        end
      end
    when Scene::Game::Menu
      if Application.savedata_game.system.embodied
        push_scene(Scene::Game::Map, Scene::Game::Map::Param::Event.new(prev_scene.item_to_use))
      else
        push_scene(Scene::Game::Title)
      end
    when Scene::Game::Menu::ItemSelect
      push_scene(Scene::Game::Map, Scene::Game::Map::Param::Item.new(prev_scene.exit_code))
    when Scene::Game::Help
      push_scene(Scene::Game::Map)
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
        push_scene(Scene::Game::Map)
      end
    when Scene::Game::OverView
      push_scene(Scene::Game::Map)
    when Scene::Game::Battle
      if Application.savedata_game.system.embodied
        push_scene(Scene::Game::Map, prev_scene.result)
      else
        Application.savedata_game.reset_for_restart
        Application.savedata_game.flags.ending_type = Definition::Game::EndingType::GAME_OVER
        push_scene(Scene::Game::Title)
      end
    else
      quit
    end
  end

end

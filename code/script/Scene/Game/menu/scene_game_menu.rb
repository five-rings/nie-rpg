=begin
  フィールドメニュー画面  
=end
class Scene::Game::Menu < Itefu::Scene::Base
  attr_reader :message
  attr_reader :item_to_use
  
  def on_initialize(start = nil)
    @message = Application.language.load_message(:menu)
    case start
    when :synth
      push_scene(Scene::Game::Menu::Synth, @message)
    else
      Application.instance.save_savedata
      push_menu_top
    end
  end
  
  def on_finalize
    Application.language.release_message(:menu)
  end
  
  def on_resume(prev_scene)
    case prev_scene
    when Scene::Game::Menu::Top
      case prev_scene.exit_code
      when :save
        push_scene(Scene::Game::Menu::Save, @message)
      when :item
        push_scene(Scene::Game::Menu::Item, @message)
      when :skill
        push_scene(Scene::Game::Menu::Skill, @message, prev_scene.member_index)
      when :equip
        push_scene(Scene::Game::Menu::Equipment, @message, prev_scene.member_index)
      when :episode
        push_scene(Scene::Game::Menu::Episode, @message)
      else
        quit
      end
    when Scene::Game::Menu::Save
      if Application.savedata_game.system.embodied
        push_menu_top(prev_scene)
      else
        quit
      end
    when Scene::Game::Menu::Item
      if Application.savedata_game.system.embodied
        if prev_scene.exit_code
          @item_to_use = prev_scene.exit_code
          quit
        else
          push_menu_top(prev_scene)
        end
      else
        if prev_scene.exit_code
          # アイテムを使ったか棄てたかでゲームオーバー状態になった
          # 終了＝初期マップに戻す
          quit
        else
          # 初期マップのときのみはメニューに戻す
          push_menu_top(prev_scene)
        end
      end
    when Scene::Game::Menu::Synth
      quit
    else
      push_menu_top(prev_scene)
    end
  end

  def push_menu_top(prev_scene = nil)
    cursor = case prev_scene
             when Scene::Game::Menu::Save
               :save
             when Scene::Game::Menu::Item
               :item
             when Scene::Game::Menu::Skill
               :skill
             when Scene::Game::Menu::Equipment
               :equip
             when Scene::Game::Menu::Episode
               :episode
             end
    push_scene(Scene::Game::Menu::Top, @message, cursor)
  end

end

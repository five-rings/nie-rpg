=begin
  デバッグ用シーンのうち最初に呼ばれるルートシーン
=end
class Scene::Debug::Menu < Itefu::TestScene::Menu

  def menu_list(m)
    this = self
    m.instance_eval do
      add_item("Debug Play", this.method(:start_debug_play))
      add_item("New Game", this.method(:start_new_game))
      add_item("Resume Game", this.method(:resume_game))
      add_item("Load Game", Scene::Debug::Menu::LoadGame, Filename::SaveData::PATH)
      add_item("Battle Test", Scene::Debug::Battle)
    add_separator
      add_item("Convert All Resources", this.method(:convert_all_resources))
      add_item("Layout", Scene::Debug::Menu::Layout, "../code/layout")
      add_item("Text", Scene::Debug::Menu::Text, "data/language/text")
      add_item("Description", Scene::Debug::Menu::Description, "")
      add_item("Skill Animation", Scene::Debug::Menu::SkillAnimation)
    add_separator
      add_item("(Itefu: Test Scene)", Itefu::TestScene::Menu)
    add_separator
      add_item("Exit", :exit)
    end
  end
  
  def on_initialize(*args)
    fade = Application.fade
    fade.resolve(0) if fade.faded_out?
  end
  
  def on_item_selected(index, id, *args)
    case id
    when :exit
      quit
    else
      super
    end
  end
  
  def convert_all_resources
    ITEFU_DEBUG_PROCESS Filename::Tool::CONVERT_RESOURCES
    ITEFU_DEBUG_OUTPUT_NOTICE "Finished to Convert All Resources"
  end
  
  def start_new_game
    Application.load_game { SaveData.new_game }
    switch_scene(Scene::Game, false)
  end
  
  def resume_game
    Application.load_game { SaveData.load_game_temp_or_new }
    switch_scene(Scene::Game, true)
  end
  
  def start_debug_play
    Application.load_game { SaveData.new_data }
    Application.savedata_game.reset_for_debug_play
    switch_scene(Scene::Game, true)
  end
  
end

=begin
  layoutフォルダにあるファイルを一覧し選択させる  
=end
class Scene::Debug::Menu::Layout < Itefu::TestScene::Layout::List

  def preview_klass
    Scene::Debug::Menu::Layout::Preview
  end

  def add_system_menu(m)
    m.add_item("Back", :back)
    m.add_item("Convert All", :convert_all) if top_directory?
  end

   def on_item_selected(index, data)
    case data
    when :convert_all
      convert_all
    else
      super
    end
  end
  
  def convert_all
    ITEFU_DEBUG_PROCESS Filename::Tool::CONVERT_LAYOUT
    ITEFU_DEBUG_OUTPUT_NOTICE "Finished to Convert Layout Data"
  end

end

class Scene::Debug::Menu::Layout::Preview < Itefu::TestScene::Layout::Preview
  def root_control_klass
    Layout::Control::Root::Debug
  end
end

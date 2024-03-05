=begin
  デバッグ用シーンのうち最初に呼ばれるルートシーン
=end
class Scene::Debug::Root < Itefu::Scene::DebugRoot
  
  def root_scene
    Scene::Debug::Menu
  end

end

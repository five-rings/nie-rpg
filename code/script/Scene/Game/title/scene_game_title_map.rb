=begin
  タイトル画面代わりのマップ 
=end
class Scene::Game::Title::Map < Scene::Game::Map

  def on_initialize(*args)
    view = Application.resident_resource(:map_view, Map::View)
    view.finalize_animations
    super

    @to_show_notice_shift_for_dash = true
  end

end

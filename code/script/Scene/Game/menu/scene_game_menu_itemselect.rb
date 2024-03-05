=begin
  アイテム選択イベント用
=end
class Scene::Game::Menu::ItemSelect < Scene::Game::Menu::Item

  def on_initialize(message)
    @scenegraph = Itefu::SceneGraph::Root.new
    @scenegraph.add_child(Itefu::SceneGraph::Sprite,
      Graphics.width, Graphics.height,
      Application.snapshot
    ).tap {|node|
      node.sprite.opacity = 0x7f
    }

    super

    control(:sidemenu).tap do |control|
      control.add_callback(:canceled, method(:on_sidemenu_canceled))
    end
  end

  def on_finalize
    super
    @scenegraph.finalize
  end

  def on_update
    super
    @scenegraph.update
  end

  def on_draw
    super
    @scenegraph.draw
  end

  def setup_action
    @viewmodel.actions.modify [:item_select]
  end

  def item_usable?(item)
    true
  end

  def on_sidemenu_canceled(control, index)
    exit(RPG::BaseItem.new) # dummy
    clear_focus
  end

  def on_action_list_decided(control, index, x, y)
    exit(@target_item)
    clear_focus
  end

end


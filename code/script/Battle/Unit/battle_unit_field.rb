=begin
  戦闘画面の背景を表示する
=end
class Battle::Unit::Field < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::FIELD; end
  include Itefu::Resource::Loader

  def on_initialize(viewport, floor_name, wall_name)
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, viewport)

    change(floor_name, wall_name)
    @scene_root.update
    @scene_root.draw
  end

  def on_finalize
    if @scene_root
      @scene_root.finalize
      @scene_root = nil
    end
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, nil)
    release_all_resources
  end

  def on_update
    @scene_root.update
  end

  def on_draw
    @scene_root.draw
  end

  def change(floor_name, wall_name)
    if floor_name.empty? && wall_name.empty?
      load_image_from_screenshot
    else
      load_image_from_battleback(floor_name, wall_name)
    end
  end

  def load_image_from_screenshot
    w = @viewport.rect.width
    h = @viewport.rect.height
    img = Application.snapshot

    @scene_root.finalize if @scene_root
    @scene_root = Itefu::SceneGraph::Root.new
    @scene_root.add_child(Itefu::SceneGraph::Sprite, w, h, img).tap {|node|
      node.sprite.viewport = @viewport
    }
  end

  def load_image_from_battleback(floor_name, wall_name)
    w = @viewport.rect.width
    h = @viewport.rect.height

    @scene_root.finalize if @scene_root
    @scene_root = Itefu::SceneGraph::Root.new

    # load images
    ids = []
    ids << load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::FLOOR_s % floor_name)
    ids << load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::WALL_s % wall_name)

    # setup sprite nodes
    ids.each do |id|
      res_data = resource_data(id)
      @scene_root.add_child(Itefu::SceneGraph::Sprite, w, h, res_data).tap {|node|
        node.sprite.viewport = @viewport
        node.sprite.zoom_x = w.to_f / res_data.width if w > res_data.width
        node.sprite.zoom_y = h.to_f / res_data.height if h > res_data.height
      } unless res_data.empty?
    end
  end

end

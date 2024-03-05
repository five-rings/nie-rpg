=begin
=end
class Map::Unit::Ui < Map::Unit::Composite
  def default_priority; Map::Unit::Priority::UI; end
  def message_unit; unit(Message.unit_id); end
  def shop_unit; unit(Shop.unit_id); end

  def on_initialize(viewport, viewport_window, map_view)
    @priority_index = 0
    @map_view = map_view
    add_sub_unit(Guide, viewport_window)
    add_sub_unit(Message, viewport, map_view)
    add_sub_unit(Shop, viewport, map_view)
    @map_view.viewmodel.assign_viewport(viewport)
  end

  def on_finalize
    @map_view.viewmodel.assign_viewport(nil)
  end
  
  def update_cursor(x, y)
    unit(Guide.unit_id).update_cursor(x, y)
  end
  
  def operate_click(x, y)
    unit(Guide.unit_id).operate_click(x, y)
  end

  def reset_guide
    unit(Guide.unit_id).reset
  end

  def open_guide(all_hint = true)
    unit(Guide.unit_id).open(all_hint)
  end

  def set_guide_auto_open(to_open, to_be_long)
    unit(Guide.unit_id).set_auto_open(to_open, to_be_long)
  end

  def show_map_name(map_name)
    @map_view.viewmodel.map_name.map_name = map_name
    @anime_map_name = @map_view.play_animation(:map_name, :show)
  end

  def hide_map_name
    if @anime_map_name && @anime_map_name.playing?
      @anime_map_name.finish
    end
  end

  def show_notice(message)
    @map_view.viewmodel.map_notice.message = message
    @anime_map_notice = @map_view.play_animation(:map_popnotice, :show)
  end

  def notice_showing?
    @anime_map_notice && @anime_map_notice.playing?
  end
  
private

  def add_sub_unit(klass, *args)
    @priority_index += 1
    add_unit_with_priority(@priority_index, klass, *args)
  end
  
end

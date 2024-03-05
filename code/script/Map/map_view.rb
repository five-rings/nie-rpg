=begin  
=end
class Map::View
  include Layout::View
  attr_reader :viewmodel
  
  def initialize
    super
    @viewmodel = Map::ViewModel.new
    @dummy_viewport = Itefu::Rgss3::Viewport.new.tap {|vp| vp.visible = false }
    load_layout("map/base", @viewmodel)
  end
  
  def clear
    if @dummy_viewport.disposed?
      self.viewport = self.effect_viewport = nil
      @viewmodel.assign_viewport(nil)
    else
      self.viewport = self.effect_viewport = @dummy_viewport
      @viewmodel.assign_viewport(@dummy_viewport)
    end
  end
  
  def finalize
    finalize_layout
    @dummy_viewport.dispose
    @dummy_viewport = nil
  end
  
  def update
    update_layout
  end
  
  def draw
    draw_layout
  end
  
end

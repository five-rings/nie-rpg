=begin
  決定演出  
=end
class Animation::Decide < Itefu::Animation::KeyFrame

  def on_initialize(target_sprite)
    super()
    auto_finalize
    target_sprite.ref_attach
    self.default_target = target_sprite

    c = bezier(0.09,1,0.28,1)
    add_key 0, :zoom_x, 1.0, c
    add_key 5, :zoom_x, 3.0
    add_key 30, :zoom_x, 3.2
    add_key 0, :zoom_y, 1.0, c
    add_key 5, :zoom_y, 3.0
    add_key 30, :zoom_y, 3.2
    add_key 0, :opacity, 0xaf
    add_key 5, :opacity, 0x1f
    add_key 30, :opacity, 0
  end
  
  def on_finalize
    self.default_target = self.default_target.swap(nil)
    super
  end
  
end
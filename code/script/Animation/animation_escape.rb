=begin
  戦闘の逃走演出
=end
class Animation::Escape < Itefu::Animation::KeyFrame

  def on_initialize(target_mapobj)
    super()
    auto_finalize
    self.default_target = target_mapobj
    base_y = target_mapobj.sprite.oy

    add_key  0, :direction, Itefu::Rgss3::Definition::Direction::DOWN, step_begin
    add_key 10, :pattern, 0
    add_key 30, :pattern, 20/4

    assign_target :oy, target_mapobj.sprite
    add_key 10, :oy, base_y
    add_key 30, :oy, base_y-120
    assign_target :opacity, target_mapobj.sprite
    add_key 30, :opacity, 0, step_begin
  end

  def on_finalize
    self.default_target = nil
    super
  end

end

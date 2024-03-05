=begin
  戦闘の勝利演出
=end
class Animation::Winning < Itefu::Animation::KeyFrame

  def on_initialize(target_mapobj)
    super()
    auto_finalize
    self.default_target = target_mapobj

    add_key  60, :direction, Itefu::Rgss3::Definition::Direction::DOWN, step_begin
  end

  def on_finalize
    self.default_target = nil
    super
  end

end

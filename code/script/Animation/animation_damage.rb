=begin
  戦闘のダメージ演出
=end
class Animation::Damage < Itefu::Animation::KeyFrame

  def on_initialize(target_mapobj, target = :ox)
    super()
    auto_finalize
    return if target_mapobj.sprite.disposed?
    self.default_target = target_mapobj
    base_x = target_mapobj.sprite.send(target)
    ampl = 2
    rate = 2

    assign_target target, target_mapobj.sprite
    add_key rate * 0, target, base_x
    add_key rate * 1, target, base_x-ampl
    add_key rate * 3, target, base_x+ampl
    add_key rate * 5, target, base_x-ampl
    add_key rate * 7, target, base_x+ampl
    add_key rate * 8, target, base_x
  end

  def on_finalize
    self.default_target = nil
    super
  end

  class Short < Itefu::Animation::KeyFrame
    def on_initialize(target_mapobj, target = :ox)
      super()
      auto_finalize
      return if target_mapobj.sprite.disposed?
      self.default_target = target_mapobj
      base_x = target_mapobj.sprite.send(target)
      ampl = 2
      rate = 2

      assign_target target, target_mapobj.sprite
      add_key rate * 0, target, base_x
      add_key rate * 1, target, base_x+ampl
      add_key rate * 3, target, base_x-ampl
      add_key rate * 5, target, base_x+ampl
      add_key rate * 6, target, base_x
    end

    def on_finalize
      self.default_target = nil
      super
    end
  end

end

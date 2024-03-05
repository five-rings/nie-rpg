=begin
=end
class Battle::Unit::Damage < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::DAMAGE; end

  def on_initialize(viewport)
  end

  def add(target, value, size = 20, color = Itefu::Color.Red, out_color = Itefu::Color.Black, sound = nil, damagetype = nil)
    type = Battle::Unit::Battler::DamageType::NORMAL
    case
    when damagetype.critical
      type = Battle::Unit::Battler::DamageType::WEAKPOINT
    when damagetype.weakpoint
      type = Battle::Unit::Battler::DamageType::WEAKPOINT
    when damagetype.resisted
      type = Battle::Unit::Battler::DamageType::RESISTED
    end if damagetype
    target.show_damage(value, size, color, out_color, nil, sound, type)
  end

  # 通常ダメージの表記を詳しくする用
  def add_ex(target, agent, value, rate, sound, damagetype)
    size = 20 * rate
    color = damagetype.critical ? Itefu::Color.Yellow : Itefu::Color.Red
    out_color = damagetype.critical ? Itefu::Color.Red : Itefu::Color.Black
    type = Battle::Unit::Battler::DamageType::NORMAL
    case
    when damagetype.critical
      type = Battle::Unit::Battler::DamageType::WEAKPOINT
    when damagetype.weakpoint
      type = Battle::Unit::Battler::DamageType::WEAKPOINT
    when damagetype.resisted
      type = Battle::Unit::Battler::DamageType::RESISTED
    end if damagetype
    target.show_damage(value, size, color, out_color, agent && agent.data, sound, type)
  end

  def on_update
  end

end


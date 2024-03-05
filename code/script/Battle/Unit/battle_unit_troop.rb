=begin
  敵集団(Unit::Enemy)を制御する
=end
class Battle::Unit::Troop < Battle::Unit::Composite
  def default_priority; Battle::Unit::Priority::TROOP; end

  def on_initialize(troop, viewport, viewport2)
    @view = manager
    @viewport = viewport
    @viewport2 = viewport2
    @troop = troop
    @next_enemy_index = 0
    lazy_sort do
      troop.enemies.each do |enemy|
        add_enemy(enemy)
      end
    end

    @view.control(:troop_all).tap do |c|
      c.focused = proc {
        show_cursor(true)
      }
      c.unfocused = proc {
        show_cursor(false)
      }
    end
  end

  def finalize
    db_c = Battle::SaveData::SystemData.collection
    units.each do |unit|
      id = unit.status.enemy.id
      db_c.encounter_enemy(id) if unit.appeared?
    end
    super
  end

  def show_cursor(visible)
    units.each do |unit|
      unit.show_cursor(visible) if unit.available?
    end
  end

  def add_enemy(enemy)
    unit = add_unit(Battle::Unit::Enemy, @next_enemy_index, enemy, @viewport, @viewport2)
    @next_enemy_index += 1
  end

  def find_enemy_unit(enemy)
    units.find {|unit|
      enemy.equal?(unit.status)
    }
  end

  def make_target(enemy_index)
    unit(enemy_index).make_target
  end

  def make_target_all
    @target_all ||= proc {
      units.select {|unit|
        unit.available?
      }
    }
  end

  def make_target_all_dead
    @target_all_dead ||= proc {
      units.select {|unit|
        unit.dead?
      }
    }
  end

  def make_target_random(count)
    @target_random ||= []
    @target_random[count] ||= proc {
      cs = units.select {|unit|
        unit.available?
      }
      Itefu::Utility::Array.weighted_randomly_select(cs, nil, count) {|unit|
        unit.status.hate
      }.map! {|i| cs[i] }
    }
  end

  def make_target_random_dead(count)
    @target_random_dead ||= []
    @target_random_dead[count] ||= proc {
      cs = units.select {|unit|
        unit.dead?
      }
      Itefu::Utility::Array.weighted_randomly_select(cs, nil, count) {|unit|
        unit.status.hate
      }.map! {|i| cs[i] }
    }
  end

  # 選択可能な敵のうち先頭側に近いものを一体選ぶ
  def make_target_head
    @target_head ||= proc {
      u = units.find {|unit|
        unit.available?
      }
      u && [u] || []
    }
  end

  def wiped_out?
    units.any?(&:available?).!
  end

  # 逃げやすさの平均値
  def escape_value
    count = units.count {|unit|
      unit.status.enemy.special_flag(:escape).nil?.!
    }
    return 0 if count == 0

    amount = units.inject(0) {|memo, unit|
      if v = unit.status.enemy.special_flag(:escape)
        memo + (Integer(v) rescue 0)
      else
        memo
      end
    }
    amount / count
  end

end


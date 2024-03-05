=begin
  パーティ(Unit::Actor)を制御する
=end
class Battle::Unit::Party < Battle::Unit::Composite
  def default_priority; Battle::Unit::Priority::PARTY; end

  def on_initialize(party, viewport, viewport2)
    @view = manager
    @viewport = viewport
    @viewport2 = viewport2
    @party = party
    @next_actor_index = 0
    lazy_sort do
      party.member_size.times do
        add_actor
      end
    end
  end

  def add_actor
    unit = add_unit(Battle::Unit::Actor, @next_actor_index, @party, @viewport, @viewport2)
    @next_actor_index += 1
  end

  def find_actor_unit(actor)
    index = @party.actor_index(actor.actor_id)
    units.find {|unit|
      unit.unit_id == index
    }
  end

  def make_target(user_index)
    unit(user_index).make_target
  end

  def make_target_all(sitaigeri = false)
    @target_all ||= proc {
      units.select {|unit|
        sitaigeri || unit.available?
      }
    }
  end

  def make_target_all_dead
    @target_all_dead ||= proc {
      units.reject {|unit|
        unit.available?
      }
    }
  end

  def make_target_random(count, sitaigeri = false)
    cs = units.select {|unit|
      sitaigeri || unit.available?
    }
    targets = Itefu::Utility::Array.weighted_randomly_select(cs, nil, count) {|unit|
      unit.hate
    }.map! {|i| cs[i] }
    proc { targets }
  end

  def make_target_random_dead(count)
    cs = units.reject {|unit|
      unit.available?
    }
    targets = Itefu::Utility::Array.weighted_randomly_select(cs, nil, count) {|unit|
      unit.hate
    }.map! {|i| cs[i] }
    proc { targets }
  end

  def wiped_out?
    units.any?(&:available?).!
  end

  def escape(escape_type = :escape)
    if manager.escapable
      @escaped = escape_type
    end
    @escaped
  end

  def escaped?
    @escaped
  end

  def escape_type
    @escaped
  end


  def active_only(index)
    units.each {|unit|
      unit.active = unit.unit_id == index
    }
  end

  def active_none
    units.each {|unit|
      unit.active = false
    }
  end

end


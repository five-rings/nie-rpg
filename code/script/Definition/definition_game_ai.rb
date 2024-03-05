=begin
=end
module Definition::Game::AI

  module Role
    ATTACKER  = :attacker
    HEALER    = :healer
  end

  module Range
    SINGULAR  = :singular
    PLURAL    = :plural
  end

  module Intensity
    MIGHTY  = :mighty
    RAPID   = :rapid
  end

  module PartySkill
    ON  = true
    OFF = false
  end

  module Percent
    PER_0   = 0
    PER_10  = 10
    PER_20  = 20
    PER_30  = 30
    PER_40  = 40
    PER_50  = 50
    PER_60  = 60
    PER_70  = 70
    PER_80  = 80
    PER_90  = 90
    PER_100 = 100
  end
  
  module Param
    RANGE = :range
    INTENSITY = :intensity
    PARTY_SKILL = :party_skill
    MP_PRESERVE_TO_ATTACK = :mp_attack
    MP_PRESERVE_TO_HEAL = :mp_heal
    HP_TO_HEAL = :hp_heal
  end

end

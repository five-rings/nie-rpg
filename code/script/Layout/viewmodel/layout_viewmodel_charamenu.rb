=begin
=end
class Layout::ViewModel::CharaMenu
  include Itefu::Layout::ViewModel
  attr_accessor :level, :job_name, :face_name, :face_index
  attr_observable :hp, :max_hp, :mp, :max_mp
  attr_observable :attack_detail, :defence_detail, :magic_detail, :footwork_detail, :accuracy_detail, :evasion_detail, :luck_detail
  attr_observable :state_ids, :immuned_states
  attr_reader :elements
  attr_reader :actor

  def initialize
    self.level = 0
    self.job_name = ""
    self.face_name = ""
    self.face_index = 0
    self.hp = self.max_hp = self.mp = self.max_mp = 0
    self.attack_detail = self.defence_detail = self.magic_detail = self.footwork_detail = self.accuracy_detail = self.evasion_detail = self.luck_detail = 0
    self.state_ids = []
    self.immuned_states = []

    @elements = Application.database.system.rawdata.elements.map do |element|
      element && element.empty?.! && Itefu::Layout::ObservableObject.new(0) || nil
    end
  end

  def copy_from_actor(actor)
    @actor = actor
    update
  end

  def update(actor = @actor)
    self.level = actor.level
    self.job_name = actor.job_name
    self.face_name = actor.face_name
    self.face_index = actor.face_index
    self.state_ids = actor.states
    update_status(actor)
  end

  # 通常のステータス表示
  def update_status(actor = @actor)
    self.hp = actor.hp
    self.max_hp = actor.max_hp
    self.mp = actor.mp
    self.max_mp = actor.max_mp
    self.attack_detail   = "#{actor.attack_raw}%+d"   % actor.attack_equip
    self.defence_detail  = "#{actor.defence_raw}%+d"  % actor.defence_equip
    self.magic_detail    = "#{actor.magic_raw}%+d"    % actor.magic_equip
    self.footwork_detail = "#{actor.footwork_raw}%+d" % actor.footwork_equip
    self.accuracy_detail = "#{actor.accuracy_raw}%+d" % actor.accuracy_equip
    self.evasion_detail  = "#{actor.evasion_raw}%+d"  % actor.evasion_equip
    self.luck_detail  = "#{actor.luck - actor.luck_equip}%+d"  % actor.luck_equip

    update_registance(actor)
  end
  
  def update_registance(actor = @actor)
    @elements.each.with_index do |value, i|
      value.value = actor.element_resistance(i) if value
    end

    self.immuned_states.modify actor.immuned_states
  end

  def cache_status(actor = @actor)
    @mhp = actor.mhp
    @mmp = actor.mmp
    @attack = actor.attack
    @defence = actor.defence
    @magic = actor.magic
    @footwork = actor.footwork
    @accuracy = actor.accuracy
    @evasion = actor.evasion
    @luck = actor.luck
  end

  # 装備変更時のステータス
  def update_equip(actor = @actor)
    self.hp = actor.hp
    self.max_hp = actor.max_hp
    self.mp = actor.mp
    self.max_mp = actor.max_mp
    self.attack_detail = format("%d %+d", actor.attack, actor.attack - @attack)
    self.defence_detail = format("%d %+d", actor.defence, actor.defence - @defence)
    self.magic_detail = format("%d %+d", actor.magic, actor.magic - @magic)
    self.footwork_detail = format("%d %+d", actor.footwork, actor.footwork- @footwork)
    self.accuracy_detail = format("%d %+d", actor.accuracy, actor.accuracy - @accuracy)
    self.evasion_detail = format("%d %+d", actor.evasion, actor.evasion - @evasion)
    self.luck_detail = format("%d %+d", actor.luck, actor.luck - @luck)

    update_registance(actor)
  end

end



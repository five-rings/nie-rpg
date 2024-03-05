=begin
=end
class Layout::ViewModel::Dialog::Chara
  include Itefu::Layout::ViewModel

  # 選択肢の前に表示する文章
  attr_observable :message

  # 選択対象のキャラのデータ
  attr_observable :actors

  class ActorData
    include Itefu::Layout::ViewModel
    attr_observable :actor_id, :chara_name, :chara_index, :hp, :mhp, :mp, :mmp, :hp_rate, :mp_rate, :exp, :exp_rate, :states

    def initialize(actor)
      @actor = actor
      update
    end
    
    def update(actor = @actor)
      self.actor_id = actor.actor_id
      self.chara_name =actor.chara_name
      self.chara_index = actor.chara_index
      self.hp = actor.hp
      self.mhp = actor.mhp
      self.mp = actor.mp
      self.mmp = actor.mmp
      self.hp_rate = actor.hp.to_f / actor.mhp
      self.mp_rate = actor.mp.to_f / actor.mmp
      self.exp = actor.exp
      self.exp_rate = actor.exp.to_f / actor.exp_next
      db = Application.database.states
      self.states = actor.states.map {|state_id| db[state_id].icon_index }
    end
  end

  def initialize
    self.message = ""
    self.actors = []
  end

  def self.actor_data(actor)
    ActorData.new(actor)
  end

end


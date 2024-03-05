=begin
  能力強化／弱体化
=end
module SaveData::Game::Actor::Buff
  attr_reader :buffs
  attr_reader :debuffs

  class Data < Hash
    def marshal_dump
      Hash[self]
    end

    # アイテムIDで保存されたアイテムを実アイテムに復旧して読み込む
    def marshal_load(objs)
      self.replace(objs)
      self.default_proc = proc {|h, k| h[k] = [] }
    end

    def initialize(*args)
      super
      self.default_proc = proc {|h, k| h[k] = [] }
    end
  end

  def initialize(*args)
    @buffs = Data.new
    @debuffs = Data.new
    super
  end

  def clear_all_buffs
    @buffs.clear
  end

  def clear_all_debuffs
    @debuffs.clear
  end

  def add_buff(id, count)
    @buffs[id] << count
  end

  def remove_buff(id)
    @buffs[id].clear
  end

  def add_debuff(id, count)
    @debuffs[id] << count
  end

  def remove_debuff(id)
    @debuffs[id].clear
  end

  def ease_buffs
    ease(@buffs)
  end

  def ease_debuffs
    ease(@debuffs)
  end

  def ease(data)
    data.each do |k, v|
      v.keep_if do |v|
        v -= 1
        v > 0
      end
    end
  end

  def buff_count(id)
    @buffs[id].size
  end

  def debuff_count(id)
    @debuffs[id].size
  end

end


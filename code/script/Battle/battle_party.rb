=begin
  戦闘中のパーティ情報
=end
class Battle::Party
  # attr_reader :actors

  def initialize
    @actors = []
  end

  def setup_from_savedata(savedata_game)
    @party = savedata_game.party
    @actors_data = savedata_game.actors
    @party.members.each do |actor_id|
      add_actor(actor_id)
    end

    @inventory = savedata_game.inventory
    @important = savedata_game.important
  end

  def add_actor(actor_id)
    return unless actor = @actors_data[actor_id]
    actor.clamp_hp_mp
    @actors << actor
  end

  def member_size
    @actors.size
  end

  def commandable_member_size
    @actors.count {|actor| actor.auto_battle?.! }
  end


  # --------------------------------------------------
  # accessors to actors

  def copy_actor_data(index, target, *args)
    return unless actor = @actors[index]
    args.each do |key|
      target.send(:"#{key}=", actor.send(key))
    end
  end

  def actor_index(actor_id)
    @actors.index {|actor|
      actor.actor_id == actor_id
    }
  end

  def actor_data(index); @actors[index].actor; end
  def icon_index(index); @actors[index].actor.special_flag(:icon_index); end
  def face_name(index); @actors[index].face_name; end
  def face_index(index); @actors[index].face_index; end
  def chara_name(index); @actors[index].chara_name; end
  def chara_index(index); @actors[index].chara_index; end

  def hp(index); @actors[index].hp; end
  def mhp(index); @actors[index].mhp; end
  def mp(index); @actors[index].mp; end
  def mmp(index); @actors[index].mmp; end
  def states(index); @actors[index].states; end
  def state_data(index); @actors[index].state_data; end
  def skills(index); @actors[index].skills; end
  def dead?(index); @actors[index].dead?; end
  def alive?(index); @actors[index].alive?; end

  def uncontrollable?(index); @actors[index].uncontrollable?; end
  def unmovable?(index); @actors[index].unmovable?; end

  def status(index); @actors[index]; end

  # --------------------------------------------------
  # accessors to inventory

  def inventory_each(&block)
    @inventory.items.each(&block)
  end

  def add_item(item, count = 1)
    @inventory.add_item(item, count)
  end

  def number_of_item(item_id)
    @inventory.number_of_item_by_id(item_id)
  end

  # アイテムを使用した扱いで減らす
  def consume_item_by_id(item_id, count = 1)
    item = @inventory.find_item_by_id(item_id)
    # 消費
    # ret = @inventory.remove_item_by_id(item_id, count)
    ret = @inventory.remove_item(item, count)
    # 減らせ多分だけ大事なものを骨董商へ
    if Game::Agency.important_item?(item)
      @important.add_item(item, count+ret)
    end
    ret
  end

  # 消耗品を個数が足りていれば使用した扱いで減らす
  def consume_item_if_possible(item, count = 1)
    if item.consumable
      ret = count <= @inventory.number_of_item(item)
      if ret
        # 消費
        @inventory.remove_item(item, count)
        # 大事な物を骨董商へ
        if Game::Agency.important_item?(item)
          @important.add_item(item, count)
        end
      end
    else
      # 非消費アイテム
      ret = true
    end
    if ret
      @inventory.replace_item(item)
    end
    ret
  end

  def consume_mp_if_possible(index, cost)
    if cost <= mp(index)
      @actors[index].add_mp(-cost)
    end
  end

  def change_equipment(index, item, position = nil)
    if @inventory.has_item?(item)
      position ||= Definition::Game::Equipment.convert_from_rgss3(item.etype_id)
      if old = @actors[index].equipment(position)
        @inventory.add_item(old)
        @inventory.replace_item(old, 1)
      end
      @inventory.remove_item(item)
      @actors[index].equip(position, item)
      old
    end
  end

  def add_money(money)
    @party.add_money(money)
  end

end


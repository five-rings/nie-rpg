=begin
  アイテム合成画面
=end
class Scene::Game::Menu::Synth < Scene::Game::Base
  include Layout::View

  def on_initialize(message)
    @message = message
    @viewmodel = ViewModel.new(message)
    load_layout("menu/synth", @viewmodel)
    @status = EquipItemStatus.new

    # アイテム一覧
    control(:itemlist).tap do |control|
      control.focused = method(:on_itemlist_focused)
      control.cursor_decidable = method(:on_itemlist_decidable)
      control.add_callback(:decided, method(:on_itemlist_decided))
      control.add_callback(:constructed_children, method(:on_itemlist_constructed_children))
      control.add_callback(:cursor_changed, method(:on_itemlist_cursor_changed))
    end

    # 強化部位選択
    control(:slotlist).tap do |control|
      control.focused = method(:on_slotlist_focused)
      control.add_callback(:decided, method(:on_slotlist_decided))
      control.add_callback(:canceled, method(:on_slotlist_canceled))
      control.add_callback(:cursor_changed, method(:on_slotlist_cursor_changed))
    end

    # 数値入力
    control(:item_numeric_dial).tap do |control|
      control.add_callback(:decided, method(:on_numeric_decided))
    end

    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end

  def on_finalize
    Application.focus.pop
    finalize_layout

    # ステータスが変わっている可能性があるのでリセットする
    actors = Application.savedata_game.actors
    Application.savedata_game.party.members.each do |actor_id|
      if actor = actors[actor_id]
        actor.clamp_hp_mp
      end
    end
  end

  def on_update
    update_layout
  end

  def on_draw
    draw_layout
  end

  def on_enter_main
    setup_selecting_item
    push_focus(:itemlist)
  end

  def on_update_main
    if focus.empty?
      exit
    end
  end


  # --------------------------------------------------
  # アイテム一覧

  def on_itemlist_constructed_children(control, items)
    if @target_item
      c = control.child_at(control.cursor_index)
      if c && c.item && control.focused?
        @viewmodel.description = c.item.description
        update_focus_to_medium(c.item)
      end
    else
      if item = control.items[control.cursor_index || 0]
        @viewmodel.description = item.description
        update_slot_info(item)
      end
    end
  end

  def on_itemlist_focused(control)
    if @target_item
      c = control.child_at(control.cursor_index)
      if c && c.item
        item = c.item
      end
      @viewmodel.description = item && item.description || ""
      update_focus_to_medium(item)
    end
  end

  def on_itemlist_decidable(control, index)
    if @target_item
      true
    else
      on_item_decidable(control, index)
    end
  end

  def on_itemlist_decided(control, index, x, y)
    if @target_item
      on_material_decided(control, index, x, y)
    else
      on_item_decided(control, index, x, y)
    end
  end

  def on_itemlist_cursor_changed(control, next_index, current_index)
    if @target_item
      on_material_cursor_changed(control, next_index, current_index)
    else
      on_item_cursor_changed(control, next_index, current_index)
    end
  end


  # --------------------------------------------------
  # 強化対象アイテム一覧

  def setup_selecting_item
    # インベントリのアイテムを追加
    inventory = Application.savedata_game.inventory
    items = inventory.items.each_key.select {|item|
      RPG::EquipItem === item &&
        item.special_flag(:material).nil? &&
        item.special_flag(:hidden).! &&
        (item.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::WEAPON ||
         item.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::SHIELD && item.special_flag(:magicscroll)) &&
        item.type_id != 0
    }

    # インベントリになく装備しているアイテムを追加
    actors = Application.savedata_game.actors
    Application.savedata_game.party.members.each {|actor_id|
      actor = actors[actor_id]
      actor.equipments.each_value do |equipment|
        next unless equipment
        next unless equipment.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::WEAPON ||
                    (equipment.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::SHIELD && equipment.special_flag(:magicscroll))
        next if inventory.has_item?(equipment)
        items << equipment
      end
    }
    if items.empty?
      items << nil
    else
      items.sort!
    end

    items << nil if items.size % 2 != 0 && items.size > 1
    @viewmodel.items.modify items
    @target_item = nil
  end

  def on_item_decidable(control, index)
    control.child_at(index).item.nil?.!
  end

  def on_item_decided(control, index, x, y)
    return unless on_item_decidable(control, index)
    @target_item = @viewmodel.items[index]
    @target_item_index = index
    setup_selecting_material(@target_item)
    control.cursor_index = 0
    control.scroll_to_child(0)

    c = push_focus(:slotlist)
    c.cursor_index = 0

    update_slot_info(@target_item)
  end

  def on_item_cursor_changed(control, next_index, current_index)
    if c = control.child_at(next_index)
      if item = c.item
        @viewmodel.description = item.description
        update_slot_info(item)
      end
    end
  end

  def update_slot_info(item)
    if RPG::Weapon === item
      slots = [nil] * Application.savedata_game.system.slot_of_weapon
    else
      slots = [nil] * Application.savedata_game.system.slot_of_armor
    end
    if extra_items = item.extra_items
      num_hidden = extra_items.count {|item_data| item_data && item_data.item.special_flag(:hidden) }
      if num_hidden > 0
        slots += [nil] * num_hidden
      end
      extra_items.each.with_index do |item_data, i|
        slots[i] = item_data if item_data
      end
    end
    @viewmodel.slots.modify slots
    @viewmodel.target_item = item
    @status.item = item
    update_extra_description(@status)
  end

  def update_extra_description(status)
    states = Application.database.states
    texts = []

    # 今装備しているキャラ
    actors = Application.savedata_game.actors
    actor = Application.savedata_game.party.members.find {|actor_id|
      actor = actors[actor_id]
      actor && actor.equipped?(status.item)
    }
    actor = actor && actors[actor]

    # キャラ表示
    if actor
      @viewmodel.equipped = true
      @viewmodel.actors.modify [actor]
    else
      @viewmodel.equipped = false
      # 装備可能なキャラ
      @viewmodel.actors.modify Application.savedata_game.party.members.map {|actor_id|
        actor = actors[actor_id]
        actor && actor.able_to_equip?(status.item) && actor || nil
      }.compact
    end

    # レベル
    if RPG::Weapon === @target_item && actor
      @viewmodel.level = actor.level
    else
      @viewmodel.level = nil
    end


    # 基礎パラメータ
    Itefu::Rgss3::Definition::Status::Param.constants.each do |key|
      id = Itefu::Rgss3::Definition::Status::Param.const_get(key)
      name = @message.text(key)
      texts << "#{name}x#{v}" if (v = status.param_rate1(id)) != 1.0
      v = status.param_rate2(id) + status.param_base(id)
      texts << "#{name}+#{v}" if v != 0
    end
    # 運
    if (v = status.luck) != 0
      texts << "#{@message.text(:luck)}+#{v}"
    end
    # 属性付与
    Application.database.system.rawdata.elements.each.with_index do |name, id|
      texts << "#{name}+#{v}" if (v = status.attack_element_level(id)) != 0
    end
    # 状態付与
    status.attack_state_ids.each do |state_id, chance|
      texts << "#{states[state_id].name}+#{chance}%"
    end
    # 属性耐性
    Application.database.system.rawdata.elements.each.with_index do |name, id|
      texts << "#{@message.text(:synth_info_anti)}#{v}" % name if (v = status.element_deduction(id)) != 0
    end
    # 状態耐性
    states.each do |state|
      texts << "#{@message.text(:synth_info_anti)}#{v}" % state.name if state && (v = status.state_resistance(state.id)) != 0
    end
    # 弱体耐性
    texts << "#{@message.text(:synth_info_anti)}#{v}" % @message.text(:weaken) if (v = status.debuff_resistance(0)) != 0

    v = status.features_filtered_with(Itefu::Rgss3::Definition::Feature::Code::ENABLED_SKILL, nil, 0) do |memo, feature|
      memo + 1
    end
    texts << "#{@message.text(:spell)}+#{v}" if v > 0

    @viewmodel.extra_texts.modify texts
  end


  # --------------------------------------------------
  # 強化部位選択

  def setup_selecting_material(item)
    type = item.class
    materials = Application.savedata_game.inventory.items.each_key.select do |entry|
      type === entry && entry.special_flag(:material) && entry.special_flag(:hidden).!
    end
    materials.sort!
    if materials.empty?
      @viewmodel.items.modify [nil]
    else
      materials << nil if materials.size % 2 != 0
      @viewmodel.items.modify [nil, nil].concat(materials)
    end
  end

  def on_slotlist_focused(control)
    update_focus_to_medium(nil)
    # @viewmodel.description = @target_item.description
  end

  def on_slotlist_decided(control, index, x, y)
    @target_slot_index = control.child_at(index).item_index
    c = control.push_focus(:itemlist)
    extitem = @target_item.embeded_extra_item(@target_slot_index)
    if extitem
      c.cursor_index = c.children.find_index {|child|
        extitem.item == child.item
      } || 0
    else
      c.cursor_index = 0
    end
  end

  def on_slotlist_canceled(control, index)
    setup_selecting_item
    control(:itemlist).tap do |c|
      c.cursor_index = @target_item_index
      c.scroll_y = 0 # 一旦スクロールを先頭に戻してから目的の位置までスクロールする
      c.scroll_to_child(@target_item_index)
    end
    @target_item_index = nil
  end

  def on_slotlist_cursor_changed(control, next_index, current_index)
    if ext_item = control.items[next_index]
      @viewmodel.description = ext_item.item.description
    else
      @viewmodel.description = @target_item.description
    end
  end


  # --------------------------------------------------
  # 素材選択

  def on_material_decided(control, index, x, y)
    if item = control.child_at(index).item
      id = item.special_flag(:material) || 0
      extitem = @target_item.embeded_extra_item(@target_slot_index)

      # 媒体アイテムが足りるかチェック
      unless id == 0 || Application.savedata_game.inventory.has_item_by_id?(id)
        # 素材がないので付け替えられないかチェック
        unless extitem && id == extitem.item.special_flag(:material)
          # 既装着分からの付け替えもできない
          medium = Application.database.items[id]
          @viewmodel.notice = sprintf(@message.text(:synth_requirement), medium.icon_index, medium.name)
          control.push_focus(:notice_message)
          return
        end
      end

      # 一枠に装着可能な数
      if RPG::Weapon === @target_item
        item_max = Application.savedata_game.system.max_embed_weapon
      else
        item_max = Application.savedata_game.system.max_embed_armor
      end

      # 装着の準備
      if item_max > 1
        if id != 0
          # 指定可能な個数を所持数内に制限
          num = Application.savedata_game.inventory.number_of_item_by_id(id)
          if extitem
            if id == extitem.item.special_flag(:material)
              num += extitem.count
            end
          end
          item_max = Itefu::Utility::Math.min(item_max, num)
        end

        @viewmodel.item_max = item_max
        @target_material = item

        c = control.push_focus(:item_numeric_dial)
        if extitem && extitem.item.equal?(item)
          # 設定しているのと同じものを選んだ場合は、既に設定している数を初期値にする
          c.number = Itefu::Utility::Math.min(item_max, extitem.count)
        else
          c.number = item_max
        end
        change_material_description(nil)
        return
      end
    end

    embed_extra_item(@target_item, @target_slot_index, item, 1)
    update_slot_info(@target_item)
    pop_focus
  end

  def on_material_cursor_changed(control, next_index, current_index)
    if c = control.child_at(next_index)
      item = c.item
    end
    change_material_description(item)
  end

  def change_material_description(item)
    if item
      # 素材
      @viewmodel.description = item.description
    else
      extitem = @target_item.embeded_extra_item(@target_slot_index)
      id = extitem && extitem.item && extitem.item.special_flag(:material) || 0
      embeded = Application.database.items[id]
      if embeded
        # なし + 装着済み
        @viewmodel.description = sprintf(@message.text(:synth_nothing_description_dsd), embeded.icon_index, embeded.name, extitem.count)
      else
        # なし + 未装着
        @viewmodel.description = @message.text(:synth_nothing_description)
      end
    end

    update_focus_to_medium(item)
  end


  # --------------------------------------------------
  # 数値入力


  def on_numeric_decided(control, index, x, y)
    count = control.number
    embed_extra_item(@target_item, @target_slot_index, @target_material, count)

    update_slot_info(@target_item)
    pop_focus
    rewind_focus(:slotlist)
  end


  # --------------------------------------------------
  #

  # 強化に必要なアイテムがどれかを強調表示する
  def update_focus_to_medium(item)
    id_to_focus = item && item.special_flag(:material) || 0
    @viewmodel.media.value.each do |medium_data|
      medium_data.focused = (medium_data.item.id == id_to_focus)
    end
  end

  # 強化に必要なアイテムの数を更新する
  def update_count_of_media
    inventory = Application.savedata_game.inventory
    @viewmodel.media.value.each do |medium_data|
      medium_data.count = inventory.number_of_item(medium_data.item)
    end
  end

  # アイテムの装脱着
  def embed_extra_item(item, slot_index, material, count)
    inventory = Application.savedata_game.inventory

    old = item.embeded_extra_item(slot_index)
    if old && (id = old.item.special_flag(:material)) && id != 0
      inventory.add_item_by_id(id, old.count)
    end

    if material && count > 0
      item.embed_extra_item(slot_index, material, count)
      if (id = material.special_flag(:material)) && id != 0
        inventory.remove_item_by_id(id, count)
      end
    else
      item.remove_extra_item(slot_index)
    end

    update_count_of_media
  end

  # 装備品のステータスを確認するためのダミー
  class EquipItemStatus
    include SaveData::Game::Actor::Feature
    attr_accessor :item
    attr_accessor :extra_description

    def initialize
      @item = RPG::EquipItem.new
      super
    end

    def item=(item)
      @item = item
      @features_cache.clear
    end

    def features_base
      @item.features
    end

    def param_base(id)
      @item.extra_params(id)
    end
  end


  # --------------------------------------------------
  #

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :items
    attr_observable :description
    attr_observable :target_item
    attr_observable :slots
    attr_observable :extra_texts
    attr_observable :item_max
    attr_observable :media
    attr_observable :notice
    attr_observable :actors
    attr_observable :level
    attr_observable :equipped

    class MediumData
      include Itefu::Layout::ViewModel
      attr_reader :item
      attr_observable :count, :focused

      def initialize(item, count, focused = false)
        @item = item
        self.count = count
        self.focused = focused
      end
    end

    def initialize(msg)
      self.items = []
      self.description = ""
      self.target_item = nil
      self.slots = []
      self.extra_texts = []
      self.item_max = 0
      self.notice = ""
      self.actors = []
      self.level = nil
      self.equipped = false

      items = Application.database.items
      inventory = Application.savedata_game.inventory
      self.media = [19, 20, 21].map {|item_id|
        item = items[item_id]
        MediumData.new(item, inventory.number_of_item_by_id(item_id))
      }
    end
  end

end


=begin
  フィールドメニューの装備画面
=end
class Scene::Game::Menu::Equipment < Scene::Game::Base
  include Layout::View
  
  def on_initialize(message, index = nil)
    @message = message
    @viewmodel = ViewModel.new(message)
    load_layout("menu/equip", @viewmodel)

    # キャラ選択
    control(:charamenu).tap do |control|
      control.add_callback(:decided, method(:on_charamenu_decided))
      control.add_callback(:cursor_changed, method(:on_charamenu_cursor_changed))
      if index
        control.cursor_index = index
        control.scroll_to_child(index)
      end
    end

    # 装備中のアイテム一覧
    control(:equiplist).tap do |control|
      control.focused = method(:on_equiplist_focused)
      control.add_callback(:cursor_changed, method(:on_equiplist_cursor_changed))
      control.add_callback(:decided, method(:on_equiplist_decided))
      control.add_callback(:canceled, method(:on_equiplist_canceled))
    end

    # アイテム一覧
    control(:itemlist).tap do |control|
      control.focused = method(:on_itemlist_focused)
      control.add_callback(:cursor_changed, method(:on_itemlist_cursor_changed))
      control.add_callback(:decided, method(:on_itemlist_decided))
      control.add_callback(:canceled, method(:on_itemlist_canceled))
    end

    Application.savedata_game.party.members.size.times.map {|i|
      [ "param_hp", "param_mp", "param_attack", "param_defence", "param_magic", "param_footwork", "param_accuracy", "param_evasion", "param_luck", ].map {|name|
        :"#{name}#{i}"
      }
    }.flatten.each do |name|
      next unless c = control(name)
      c.add_callback(:binding_value_changed, method(:on_binding_value_changed))
    end

    @status = Scene::Game::Menu::Synth::EquipItemStatus.new

    Graphics.frame_reset
    Application.focus.push(self.focus)
    update_equiplist(index || 0)
    enter
  end

  def on_finalize
    if @coloring
      # Preview中に画面を閉じた
      # 装備一覧にあったアイテムに戻して抜ける
      restore_previewing_equip
    end

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
    c = push_focus(:charamenu)
    on_charamenu_decided(c, c.cursor_index, nil, nil)
  end

  def on_update_main
    if focus.empty?
      exit
    end
  end

  def on_binding_value_changed(control, name, old_value)
    unless @font
      @font = control.font
      @font_blue = @font.clone
      @font_blue.out_color = Itefu::Color.Blue
      @font_red = @font.clone
      @font_red.color = Itefu::Color.Red
    end
    unless @coloring
      control.apply_font(@font)
      return
    end

    value = control.send(name)

    case control.name
    when /^param_(hp|mp)([0-9]+)/
      # HP/MPの色替え
      cm = @viewmodel.charamenu.value[Integer($2)]
      new = cm.send(:"max_#{$1}").value
      old = cm.instance_variable_get(:"@m#{$1}")
      if new < old
        control.apply_font(@font_red)
      elsif new > old
        control.apply_font(@font_blue)
      else
        control.apply_font(@font)
      end
    else
      # 基礎パラメータの色替え
      case value
      when / -/
        control.apply_font(@font_red)
      when / \+[^0]/
        control.apply_font(@font_blue)
      else
        control.apply_font(@font)
      end
    end
  end


  # --------------------------------------------------
  # キャラ選択

  def on_charamenu_decided(control, index, x, y)
    actor_id = Application.savedata_game.party.members[index]
    @target_actor = Application.savedata_game.actors[actor_id]

    control(:equiplist).cursor_index = 0
    control(:itemlist).cursor_index = 0
    push_focus(:equiplist)
  end

  def on_charamenu_cursor_changed(control, next_index, current_index)
    if next_index
      update_equiplist(next_index)
    end
  end

  def update_equiplist(index = @actor_index)
    @actor_index = index
    actor_id = Application.savedata_game.party.members[index]
    actor = Application.savedata_game.actors[actor_id]
    @viewmodel.update_equips(actor)
    @viewmodel.charamenu.value[@actor_index].cache_status
  end


  # --------------------------------------------------
  # 装備一覧

  def on_equiplist_focused(control)
    update_equip_description(control.cursor_index)
    update_itemlist(@target_actor, control.cursor_index)
  end

  def on_equiplist_cursor_changed(control, next_index, current_index)
    if next_index && next_index != current_index
      update_equip_description(next_index)
      update_itemlist(@target_actor, next_index)
      control(:itemlist).cursor_index = 0
    end
  end

  def update_equip_description(index)
    if equipment = @viewmodel.equips[index]
      @status.item = equipment
      @viewmodel.description = equipment.description
    else
      @status.item = nil
      @viewmodel.description = ""
    end
    update_extra_description(@status)
  end

  def update_itemlist(actor, index)
    unless type_id = Definition::Game::Equipment::Type.constants[index]
      return unless equipment = @viewmodel.equips[index]
      @viewmodel.items.modify [nil]
      @target_type = equipment.special_flag(:equip)
      return
    end
    type = Definition::Game::Equipment::Type.const_get(type_id)
    etype = Definition::Game::Equipment.convert_to_rgss3(type)

    inventory = Application.savedata_game.inventory
    items = inventory.items.each.with_object([]) do |(item, count), memo|
      next unless RPG::EquipItem === item && etype == item.etype_id
      next if item.special_flag(:material)
      next if item.special_flag(:hidden)
      next unless @target_actor.able_to_equip?(item)
      memo << ViewModel::ItemData.new(item, count)
    end
    # items.sort_by! {|item_data| item_data.item }
    items.reverse!

    if actor.equipment(type)
      items.unshift nil
    end

    @target_type = type
    @viewmodel.items.modify items
  end

  def on_equiplist_decided(control, index, x, y)
    if @viewmodel.items.value.empty?
      @viewmodel.notice = @message.text(:equip_noitem)
      control.push_focus(:notice_message)
    else
      @coloring = true
      control.push_focus(:itemlist)
    end
  end

  def on_equiplist_canceled(control, index)
    if Application.savedata_game.party.members.size <= 1
      # メンバーを選ばない場合
      pop_focus
    else
      @viewmodel.description = ""
      @viewmodel.items.modify []
      @status.item = nil
      update_extra_description(@status)
    end
  end


  # --------------------------------------------------
  # アイテム一覧

  def on_itemlist_focused(control)
    index = control.cursor_index
    update_item_description(index)
    preview_equipping_item(index)
  end

  def on_itemlist_cursor_changed(control, next_index, current_index)
    if next_index
      update_item_description(next_index)
      preview_equipping_item(next_index)
    end
  end

  def update_item_description(index)
    if item = @viewmodel.items[index]
      @viewmodel.description = item.item.description
      @status.item = item.item
    else
      @viewmodel.description = ""
      @status.item = nil
    end
    update_extra_description(@status)
  end

  def preview_equipping_item(index)
    @previewin = true
    item = @viewmodel.items[index]
    @target_actor.no_auto_clamp do
      @target_actor.equip(@target_type, item && item.item)
    end
    @viewmodel.charamenu.value[@actor_index].update_equip
  end

  def on_itemlist_decided(control, index, x, y)
    @coloring = false

    # 装備一覧にあったアイテムをインベントリに戻し
    # 選んだアイテムを装備または装備解除する
    equip_index = control(:equiplist).cursor_index
    equip = @viewmodel.equips[equip_index]
    item = @viewmodel.items[index]
    inventory = Application.savedata_game.inventory
    if equip
      case equip.etype_id
      when Fixnum
        # 通常のアイテムのみインベントリに戻す
        # @note 形代などの装備可能アイテムを装備した場合を除外する
        inventory.add_item(equip)
        inventory.replace_item(equip, 1)
      end
    end
    if item
      inventory.remove_item(item.item)
      @target_actor.no_auto_clamp do
        @target_actor.equip(@target_type, item.item)
      end
    else
      @target_actor.no_auto_clamp do
        @target_actor.remove_equip(@target_type)
      end
    end

    update_equiplist
    update_itemlist(@target_actor, control(:equiplist).cursor_index)

    cm = @viewmodel.charamenu.value[@actor_index]
    cm.update
    # 色の変更を強制適用する
    cm.max_hp.notify_changed_value(true)
    cm.max_mp.notify_changed_value(true)

    pop_focus
  end

  def on_itemlist_canceled(control, index)
    @coloring = false

    # 装備一覧にあったアイテムに戻して抜ける
    restore_previewing_equip

    update_equiplist
    update_itemlist(@target_actor, control(:equiplist).cursor_index)
    @viewmodel.charamenu.value[@actor_index].update
  end

  def restore_previewing_equip
    equip_index = control(:equiplist).cursor_index
    equip = @viewmodel.equips[equip_index]
    @target_actor.equip(@target_type, equip)
  end


  # --------------------------------------------------
  #

  # 強化パラメータの表示を更新する
  def update_extra_description(status)
    case status.item
    when RPG::Weapon
      # すべて表示する
    when RPG::Armor
      # 強化していないものは表示なし
      unless status.item.extra_item_embedded?
        @viewmodel.extra_texts = []
        return
      end
    else
      # すべて表示しない
      @viewmodel.extra_texts = []
      return
    end

    states = Application.database.states
    texts = []
    v = nil

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

    @viewmodel.extra_texts = texts
  end


  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :charamenu
    attr_observable :items, :description
    attr_observable :equips
    attr_observable :notice
    attr_observable :extra_texts
    ItemData = Struct.new(:item, :count)

    def initialize(msg)
      self.charamenu = Application.savedata_game.party.members.map {|actor_id|
        vm = Layout::ViewModel::CharaMenu.new
        vm.copy_from_actor Application.savedata_game.actors[actor_id]
        vm
      }
      self.items = []
      update_equips(nil)
      self.description = ""
      self.notice = ""
      self.extra_texts = []
    end

    def update_equips(actor)
      if actor
        self.equips = actor.equipments.map {|type_id, item|
          item
        }
      else
        self.equips = Definition::Game::Equipment::Type.constants.map { nil }
      end
    end

  end

end

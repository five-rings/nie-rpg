=begin
  フィールドメニュー/アイテム選択画面
=end
class Scene::Game::Menu::Item < Scene::Game::Base
  include Layout::View
  DIALOG_YES = 1
  FADE_TIME_TO_RESET = 1000

  NoticeEntry = Struct.new(:message, :face_name, :face_index, :sound)

  def on_initialize(message)
    @message = message
    @viewmodel = ViewModel.new(message)
    load_layout("menu/item", @viewmodel)
    @viewmodel.dialog.choices.modify [
      Application.language.message(:system, :yes),
      Application.language.message(:system, :no),
    ]

    @agent = Game::Agency::Damage.new
    @agent.add_callback(:note, method(:on_note_applied))
    @notices = []

    # 通知ウィンドウ
    control(:notice_message).tap do |control|
      notice_unfocused = control.unfocused
      control.unfocused = proc {|c|
        notice_unfocused.call(c)
        show_notice
      }
    end

    # アイテムの種類
    control(:sidemenu).tap do |control|
      control.focused = method(:on_sidemenu_focused)
      control.add_callback(:cursor_changed, method(:on_sidemenu_cursor_changed))
      control.add_callback(:decided, method(:on_sidemenu_decided))
    end

    # アイテム一覧
    control(:itemlist).tap do |control|
      control.focused = method(:on_itemlist_focused)
      control.add_callback(:cursor_changed, method(:on_itemlist_cursor_changed))
      control.add_callback(:decided, method(:on_itemlist_decided))
    end

    # アイテムへの操作方法
    control(:item_action_list).tap do |control|
      control.cursor_decidable = method(:on_action_list_decidable)
      control.add_callback(:decided, method(:on_action_list_decided))
      control.add_callback(:canceled, method(:on_action_list_canceled))
    end

    # 数値入力
    control(:item_numeric_dial).tap do |control|
      control.add_callback(:decided, method(:on_numeric_decided))
      control.add_callback(:canceled, method(:on_numeric_canceled))
    end

    # 確認ダイアログ
    control(:dialog_list).tap do |control|
      control.add_callback(:decided, method(:on_dialog_decided))
    end

    # キャラクター選択ダイアログ
    control(:dialog_chara_list).tap do |control|
      control.add_callback(:decided, method(:on_chara_list_decided))
      control.cursor_decidable = false
    end

    # パーティ全体選択ダイアログ
    control(:dialog_chara_all).tap do |control|
      control.add_callback(:decided, method(:on_chara_all_decided))
      control.cursor_decidable = false
    end


    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end

  def on_finalize
    Application.focus.pop
    finalize_layout
  end

  def on_update
    if focus.current != control(:notice_message)
      show_notice
    end
    update_layout
  end

  def show_notice
    if notice = @notices.shift
      if notice.sound
        Itefu::Sound.stop_me
        Itefu::Sound.play(notice.sound)
      end
      if notice.face_name
        @viewmodel.assign_notice_with_face(notice.message, notice.face_name, notice.face_index)
      else
        @viewmodel.assign_notice(notice.message)
      end
      push_focus(:notice_message)
    end
  end

  def on_draw
    draw_layout
  end

  def on_enter_main
    push_focus(:sidemenu)
  end

  def on_update_main
    if focus.empty?
      exit
    end
  end


  # --------------------------------------------------
  # サイドメニュー

  def on_sidemenu_focused(control)
    if item = control.items[control.cursor_index]
      update_itemlist(item.id)
    else
      raise Itefu::Exception::Unreachable
    end
    @viewmodel.description = ""
  end

  def on_sidemenu_cursor_changed(control, next_index, current_index)
    if next_index && item = control.items[next_index]
      update_itemlist(item.id)
    end
    if current_index && next_index != current_index
      c = control(:itemlist)
      c.scroll_y = 0
      c.cursor_index = 0
    end
  end

  def refresh_itemlist
    update_itemlist(@item_type)
  end

  def update_itemlist(type)
    @item_type = type
    inventory = Application.savedata_game.inventory

    items = case type
    when :item_material
      # 素材
      inventory.items.each_key.select {|item|
        item.special_flag(:material) && item.special_flag(:hidden).!
        # 素材は使用したりしないのでID順に並べる
        # 最後に全項目reverseするので逆順に並べておく
      }.sort!{|a, b| b <=> a }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item))
      }
    when :item_tool
      # その他
      inventory.select_items {|item|
        item_to_use?(item).! && item.special_flag(:material).nil? && item.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item))
      }
    when :item_usable
      # 道具
      inventory.select_items {|item|
        item_to_use?(item) && item.consumable.! && item.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item), item_usable?(item).!)
      }
    when :item_consumable
      # 消耗品
      inventory.select_items {|item|
        item_to_use?(item) && item.consumable && item.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item), item_usable?(item).!)
      }
    when :item_weapon
      inventory.select_weapons {|weapon|
        weapon.special_flag(:material).nil? && weapon.wtype_id != 0 && weapon.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item))
      }
    when :item_armor
      inventory.select_armors {|armor|
        armor.special_flag(:material).nil? &&
        armor.etype_id != Itefu::Rgss3::Definition::Equipment::Slot::ACCESSORY &&
        armor.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item))
      }
    when :item_accessory
      inventory.select_armors {|armor|
        armor.special_flag(:material).nil? &&
        armor.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::ACCESSORY &&
        armor.special_flag(:hidden).!
      }.map! {|item|
        ViewModel::ItemData.new(item, inventory.number_of_item(item))
      }
    else
      raise Itefu::Exception::Unreachable
    end
    # items.sort_by! {|item_data| item_data.item }
    items.reverse!

    items << nil if items.size % 2 != 0 && items.size > 1
    @viewmodel.items.modify items
  end

   def update_item_count
     c = control(:itemlist)
     return unless item = c.items[c.cursor_index]
     return unless t = c.child_at(c.cursor_index)
     t.value = Application.savedata_game.inventory.number_of_item(item.item)
   end

  def on_sidemenu_decided(control, index, x, y)
    if @viewmodel.items.value.empty?
      @viewmodel.assign_notice(@message.text(:item_noitem))
      control.push_focus(:notice_message)
    else
      c = control.push_focus(:itemlist)
      # c.cursor_index = 0
    end
  end


  # --------------------------------------------------
  # アイテム一覧

  def on_itemlist_focused(control)
    update_item_description(0)
  end

  def on_itemlist_cursor_changed(control, next_index, current_index, *args)
    update_item_description(next_index) if next_index
  end

  def update_item_description(index)
    if item = @viewmodel.items[index]
      @viewmodel.description = item.item.description
    else
      @viewmodel.description = ""
    end
  end

  def on_itemlist_decided(control, index, x, y)
    if item = @viewmodel.items[index]
      @target_item = item.item
      @viewmodel.item_max = item.count
      setup_action
      c = control.push_focus(:item_action_list)
      c.cursor_index = 0
      play_animation(:item_action_window, :in)
    end
  end

  def setup_action
    if item_usable?(@target_item) && Application.savedata_game.system.embodied
      @viewmodel.actions.modify [:item_use, :item_discard]
    else
      @viewmodel.actions.modify [:item_discard]
    end
  end


  # --------------------------------------------------
  # アイテムへの操作と個数

  def on_action_list_decidable(control, index)
    if c = control.child_at(index)
      if c.item == :item_use
        return false unless item_usable?(@target_item)
      end
      c.item
    end
  end

  # 今使用できる状態のアイテムか
  def item_usable?(item)
    RPG::UsableItem === item &&
    Itefu::Rgss3::Definition::Skill::Occasion.usable_in_fieldmenu?(item.occasion)
  end

  # 使用する用のアイテムか
  def item_to_use?(item)
    RPG::UsableItem === item &&
    Itefu::Rgss3::Definition::Skill::Occasion::UNUSABLE != item.occasion
  end

  def on_action_list_decided(control, index, x, y)
    if @action_mode = on_action_list_decidable(control, index)
      if @action_mode == :item_use
        @action_count = 1
        setup_dialog_to_select_chara
        if Itefu::Rgss3::Definition::Skill::Scope.to_singular?(@target_item.scope) && @target_item.special_flag(:menu_target) != "all"
          switch_focus(:dialog_chara_list)
        else
          switch_focus(:dialog_chara_all)
        end
        play_animation(:item_action_window, :out)
      else
        c = control.push_focus(:item_numeric_dial)
        c.number = 1
        play_animation(:item_numeric_window, :in)
      end
    end
  end

  def on_action_list_canceled(control, index)
    play_animation(:item_action_window, :out)
  end

  def on_numeric_decided(control, index, x, y)
    @action_count = control.number
    if @action_count <= 0
      control.pop_focus
      play_animation(:item_numeric_window, :out)
    else
      setup_dialog_to_discard
      pop_focus
      c = switch_focus(:dialog_list)
      c.cursor_index = DIALOG_YES
      play_animation(:item_numeric_window, :out)
      play_animation(:item_action_window, :out)
    end
  end

  def on_numeric_canceled(control, index)
    play_animation(:item_numeric_window, :out)
  end


  # --------------------------------------------------
  # 捨てる

  def setup_dialog_to_discard
    @viewmodel.dialog.message = sprintf(@message.text(:item_ask_discard), @target_item.icon_index, Itefu::Utility::String.shrink(@target_item.name, Language::Locale.full? ? 17 : 30), @action_count)
  end

  def on_dialog_decided(control, index, x, y)
    case index
    when DIALOG_YES
      discard_item(@target_item, @action_count)
    end

    pop_focus
    if @viewmodel.items.value.empty?
      rewind_focus(:sidemenu)
    end
  end

  def discard_item(item, count)
    if Application.savedata_game.system.not_to_discard && item.special_flag(:not_to_discard)
      return exit(item)
    end

    inventory = Application.savedata_game.inventory
    inventory.remove_item(item, count)

    # 装備可能アイテムを装備してた場合解除する
    if position = item.special_flag(:equip)
      party = Application.savedata_game.party
      actors = Application.savedata_game.actors
      # 既に装備している個数
      count_equipped = party.members.inject(0) {|m, actor_id|
        actor = actors[actor_id]
        m + actor.number_of_equipments {|eq|
          eq && eq.special_flag(:item_id) == item.id
        }
      }
      # 超過個数
      count_equipped -= inventory.number_of_item(item)
      # 所持数以上に装備している場合に前のキャラから取り外す
      party.members.each do |actor_id|
        break unless count_equipped > 0
        actor = actors[actor_id]
        if actor.equipment(position)
          actor.remove_equip(position)
          count_equipped -= 1
        end
      end 
    end

    if Game::Agency.important_item?(item)
      important = Application.savedata_game.important
      important.add_item(item, count)
    else
      remove_all_extra_items(item)
    end

    if inventory.has_item_by_id?(1) # @magic: 追思帳を持っているか
      refresh_itemlist
    elsif Application.savedata_game.system.embodied
      # 追思帳を捨てたのでタイトルに戻す
      # 再開したときに未所持にならないよう捨てた分を足す
      inventory.add_item_by_id(1)
      Itefu::Sound.stop_bgm(FADE_TIME_TO_RESET)
      Itefu::Sound.stop_bgs(FADE_TIME_TO_RESET)
      Application.instance.save_savedata
      Application.savedata_game.reset_for_restart
      Application.savedata_game.flags.ending_type = Definition::Game::EndingType::DISCARD_JOURNAL
      exit(item)
      clear_focus
    else
      # タイトルでは追思帳を捨てられる
      refresh_itemlist
    end
  end

  def remove_all_extra_items(item)
    return unless RPG::EquipItem === item
    return unless extra_items = item.extra_items

    inventory = Application.savedata_game.inventory
    return if inventory.has_item?(item)

    extra_items.each do |extra_data|
      next unless extra_data
      id = extra_data.item.special_flag(:material)
      inventory.add_item_by_id(id, extra_data.count) if id != 0
    end
    item.clear_extra_items
  end


  # --------------------------------------------------
  # 使う

  def setup_dialog_to_select_chara
    update_chara_list_message
    actors = Application.savedata_game.actors
    targets = Application.savedata_game.party.members.map {|actor_id|
      actor = actors[actor_id]
      actor && actor.alive? && Layout::ViewModel::Dialog::Chara.actor_data(actor) || nil
    }
    targets.compact!
    @target_actors = targets
    @viewmodel.dialog_chara.actors.modify targets
  end

  def update_chara_list_message
    count = Application.savedata_game.inventory.number_of_item(@target_item)
    @viewmodel.dialog_chara.message = sprintf(@message.text(:item_ask_use), @target_item.icon_index, Itefu::Utility::String.shrink(@target_item.name, Language::Locale.full? ? 13 : 25), count)
  end

  def on_chara_list_decided(control, index, x, y)
    use_item(@target_item, @action_count, @target_actors[index, 1])
    return clear_focus if exit_code

    if Application.savedata_game.inventory.has_item?(@target_item)
      update_chara_list_message
      update_item_count
    else
      refresh_itemlist
      pop_focus
      if @viewmodel.items.value.empty?
        rewind_focus(:sidemenu)
      end
    end
  end

  def on_chara_all_decided(control, index, x, y)
    use_item(@target_item, @action_count, @target_actors)
    return clear_focus if exit_code

    if Application.savedata_game.inventory.has_item?(@target_item)
      update_chara_list_message
      update_item_count
    else
      refresh_itemlist
      pop_focus
      if @viewmodel.items.value.empty?
        rewind_focus(:sidemenu)
      end
    end
  end

  def use_item(item, count, targets)
    Itefu::Sound.play_use_item_se

    party = Application.savedata_game.party
    actors = Application.savedata_game.actors
    inventory = Application.savedata_game.inventory

    # 装備可能アイテムを装備させる
    if position = item.special_flag(:equip)
      eitem = SaveData::Game::ItemData.copy_armor_from_item(item)
      # いまから装備するキャラの分は一旦外す
      targets.each do |actor_data|
        if actor = actors[actor_data.actor_id.value]
          actor.remove_equip(position)
        end
      end
      # 既に装備している個数
      count_equipped = party.members.inject(0) {|m, actor_id|
        actor = actors[actor_id]
        m + actor.number_of_equipments {|eq|
          eq && eq.id == eitem.id
        }
      } + 1 # これから装備する分
      # 超過個数
      count_equipped -= inventory.number_of_item(item)
      # 所持数以上に装備している場合に前のキャラから取り外す
      party.members.each do |actor_id|
        break unless count_equipped > 0
        actor = actors[actor_id]
        if actor.equipment(position)
          actor.remove_equip(position)
          count_equipped -= 1
        end
      end 

      eitem = nil if count_equipped > 0
    end
    equipped = false

    # アイテムの適用
    targets.each do |actor_data|
      if actor = actors[actor_data.actor_id.value]
        apply_item(item, count, actor)
        if eitem
          actor.equipments[position] = eitem
          equipped = true
        end
      end
    end
    @viewmodel.dialog_chara.actors.value.each(&:update)

    if equipped
      fmt = @message.text(:item_equipped)
      @notices << NoticeEntry.new(fmt % item.name)
    end

    if RPG::Item === item && item.consumable
      inventory.remove_item(item, count)
    end
    inventory.replace_item(item)

    if check_if_common_event(item)
      return exit(item)
    end
  end

  def apply_item(item, count, actor)
    count.times {
      @agent.apply_item(actor, actor, item)
    }
  end

  def on_note_applied(agent, id, value, user, target, item)
    case id
    when :exp_levelup
      # レベルが上がった際の通知を指定
      exp, old_level, old_skills, old_job_name = value
      learnt_skills = target.skill_diffs(old_skills)
      return unless fmt_levelup = Application.language.message(:game, :level_up)
      return unless fmt_levelup_newjob = Application.language.message(:game, :level_up_newjob)
      return unless fmt_skill = Application.language.message(:game, :learnt_skill_indent)

      # Level Up
      if newjobname = target.job.highjob_name(target.level, old_level)
        message = sprintf(fmt_levelup_newjob, old_job_name, newjobname, old_level, target.level)
      else
        message = sprintf(fmt_levelup, target.job_name, old_level, target.level)
      end

      # Learning Skills
      while sid = learnt_skills.shift
        message << Itefu::Rgss3::Definition::MessageFormat::NEW_LINE
        message << sprintf(fmt_skill, sid)
      end

      @notices << NoticeEntry.new(message, target.face_name, target.face_index, RPG::ME.new("Victory1", 90, 95))
    end
  end


  # --------------------------------------------------
  #

  # @return [Boolean] コモンイベントを実行するアイテムかを判定する
  def check_if_common_event(item)
    return false unless RPG::UsableItem === item

    item.effects.find {|effect|
      effect.code == Itefu::Rgss3::Definition::Skill::Effect::COMMON_EVENT
    }.nil?.!
  end



  # --------------------------------------------------
  #

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :sidemenu
    MenuItem = Struct.new(:id, :label, :noticed)
    attr_observable :items
    attr_observable :description
    attr_observable :item_max
    attr_observable :actions
    attr_observable :notice
    attr_observable :face_name, :face_index
    ItemData = Struct.new(:item, :count, :disabled)
    attr_reader :dialog, :dialog_chara

    def initialize(msg)
      self.sidemenu = [
        MenuItem.new(:item_usable, msg.text(:item_usable)),
        MenuItem.new(:item_consumable, msg.text(:item_consumable)),
        MenuItem.new(:item_tool, msg.text(:item_tool)),
        MenuItem.new(:item_material,  msg.text(:item_material)),
        MenuItem.new(:item_weapon,  msg.text(:item_weapon)),
        MenuItem.new(:item_armor,  msg.text(:item_armor)),
        MenuItem.new(:item_accessory,  msg.text(:item_accessory)),
      ]
      self.items = []
      self.description = ""
      self.item_max = 0
      self.actions = []
      assign_notice("")
      @dialog = Layout::ViewModel::Dialog.new
      @dialog_chara = Layout::ViewModel::Dialog::Chara.new
    end

    def assign_notice(notice)
      self.notice = notice
      self.face_name = nil
      self.face_index = nil
    end

    def assign_notice_with_face(notice, face_name, face_index)
      self.notice = notice
      self.face_name = face_name
      self.face_index = face_index
    end
  end

end

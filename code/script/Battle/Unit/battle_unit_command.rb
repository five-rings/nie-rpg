=begin
  戦闘中のコマンド入力
=end
class Battle::Unit::Command < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::COMMAND; end
  Operation = Itefu::Layout::Definition::Operation

  Context = Struct.new(:party, :user_index, :detail_opened, :using_items)

  def on_initialize(viewport)
    @message = Application.language.load_message(:battle)
    @context = Context.new(manager.party, 0, false, Hash.new(0))

    @view = manager
    @viewmodel = ViewModel.new(viewport)

    @view.add_layout(:bottom, "battle/command", @viewmodel)
    @view.add_layout(:center, "battle/command_detail", @viewmodel)
    @view.add_layout(:bottom, "battle/command_info", @viewmodel)
    @view.add_layout(:center, "battle/confirm", @viewmodel)
    @view.add_layout(:top, "battle/state_detail", @viewmodel)
    @view.add_layout(:center, "notice", @viewmodel).tap do |control|
      control.viewport = viewport
    end

    # アイテム選択の設定
    @view.control(:command_items).tap do |control|
      control.focused = proc {
        @view.play_animation(:command_items_window, :in)
        i = control.cursor_index || 0
        apply_item_detail(i)
        reserve_action(i)
      }
      control.unfocused = proc {
        @view.play_animation(:command_items_window, :out)
        apply_item_detail(nil)
      }
      control.custom_operation = method(:operation_items)
      control.add_callback(:decided, method(:decided_items))
      control.add_callback(:canceled, method(:canceled_items))
      control.add_callback(:cursor_changed, method(:cursor_items_changed))
    end

    # コマンドメニューの設定
    @view.control(:command_menu).tap do |control|
      control.add_callback(:decided, method(:decided_menu))
      control.custom_operation = method(:operation_menu)
      control.add_callback(:cursor_changed, method(:cursor_menu_changed))
    end

    # 敵選択の設定
    @view.control(:troop).tap do |control|
      control.add_callback(:decided, method(:decided_troop))
      control.add_callback(:canceled, method(:canceled_target))
      control.add_callback(:cursor_changed, method(:cursor_target_changed))
    end

    # 敵全体選択の設定
    @view.control(:troop_all).tap do |control|
      control.add_callback(:decided, method(:decided_troop_all))
      control.add_callback(:canceled, method(:canceled_target))
    end

    # 味方選択の設定
    @view.control(:party).tap do |control|
      control.add_callback(:decided, method(:decided_party))
      control.add_callback(:canceled, method(:canceled_target))
      control.custom_operation = method(:operation_party)
    end

    # アクション確認の設定
    @view.control(:confirm).tap do |control|
      anime_in = nil
      control.focused = proc {
        anime_in = @view.play_animation(:confirm_window, :in)
      }
      control.unfocused = proc {
        anime_in.finish if anime_in
        @view.play_animation(:confirm_window, :out)
      }
      control.add_callback(:decided, method(:decided_confirm))
      control.custom_operation = method(:operation_confirm)
    end
  end

  def on_finalize
    Application.language.release_message(:battle)
  end

  # コマンドメニューの決定
  def decided_menu(control, cursor_index, x, y)
    items = case cursor_index
    when 4
      # 情報ウィンドウ
      # do nothing
      return
    when 3
      # 装備を切り替える
      party_unit = manager.party_unit
      actor_unit = party_unit.unit(@context.user_index)
      @context.party.inventory_each.map {|item, count|
        if RPG::EquipItem === item &&
            0 < count - @context.using_items[item] &&
            item.special_flag(:material).! &&
            item.special_flag(:hidden).! &&
            actor_unit.status.able_to_equip?(item)
          ViewModel::UsingItem.new(item.icon_index, item.name, item.short_name, count, item.description, 0, item)
        end
      }.reverse!
    when 2
      # アイテムを使う
      @context.party.inventory_each.map {|item, count|
        if RPG::UsableItem === item &&
            Itefu::Rgss3::Definition::Skill::Occasion.usable_in_battle?(item.occasion) &&
            item.special_flag(:hidden).! &&
            0 < count - @context.using_items[item]
          ViewModel::UsingItem.new(item.icon_index, item.name, item.short_name, count, item.description, item.speed, item)
        end
      }.tap {|cs|
        cs.compact!
        cs.sort_by!(&:item)
      }
    else
      # スキルを使う
      db_skills = @manager.database.skills
      @context.party.skills(@context.user_index).map {|skill_id|
        if (skill = db_skills[skill_id]) && Itefu::Rgss3::Definition::Skill::Occasion.usable_in_battle?(skill.occasion)
          if skill.use_all_mp?
            party_unit = manager.party_unit
            actor_unit = party_unit.unit(@context.user_index)
            cost = Itefu::Utility::Math.max(actor_unit.status.mp, skill.mp_cost)
          else
            cost = skill.mp_cost
          end
          ViewModel::UsingItem.new(skill.icon_index, skill.name, skill.short_name, cost, skill.description, skill.speed, skill)
        end
      }.tap {|cs|
        cs.compact!
        cs.sort! {|a, b|
          r = a.item.stype_id <=> b.item.stype_id
          if r != 0 && (a.item.stype_id == 2 || b.item.stype_id == 2) # @magic Magic
            r
          else
            a.item.sort_index <=> b.item.sort_index
          end
        }
        if i = cs.find_index {|action| action.item.stype_id == 2 } # @magic Magic
          # 術式を行を改めて並べる
          if i % 2 != 0
            cs.insert(i, false)

          end
        end
      }
    end

    items.compact!
    if items.empty?
      case cursor_index
      when 3
        @viewmodel.notice = @message.text(:command_noequip)
      when 2
        @viewmodel.notice = @message.text(:command_noitem)
      when 1
        @viewmodel.notice = @message.text(:command_nomagic)
      else
        @viewmodel.notice = @message.text(:command_noskill)
      end
      control.push_focus(:notice_message)
    else
      # items.sort_by!(&:item)
      items << nil if items.size % 2 != 0 && items.size > 1
      @viewmodel.items = items
      @view.control(:command_items).cursor_index = 0
      @view.push_focus(:command_items)
    end
  end

  # コマンドメニューの操作
  def operation_menu(control, code, *args)
    case code
    when Operation::CANCEL
      if @context.user_index == 0
        start_command(0)
      else
        prev_index = @context.user_index - 1
        cancel_reservation(prev_index)
        start_previous_command
      end
      nil
    when Operation::DECIDE
      @view.control(:command_items).scroll_y = 0
      code
    else
      code
    end
  end

  # コマンドメニューのカーソルの変更
  def cursor_menu_changed(control, next_index, current_index)
    index_state_detail = 4 # @magic to show state details
    if next_index == index_state_detail
      @view.play_animation(:state_detail_window, :in)
    elsif current_index == index_state_detail
      @view.play_animation(:state_detail_window, :out)
    end
  end

  # アイテム選択の決定
  def decided_items(control, cursor_index, x, y)
    case @reserved_item
    when nil
      return
    when RPG::UsableItem
      case @reserved_item.scope
      when Itefu::Rgss3::Definition::Skill::Scope::OPPONENT
        # 敵から選択
        @view.control(:troop).tap {|ctr|
          i = ctr.find_selectable_child_index(0)
          ctr.cursor_index = i
          update_command_info ctr.child_at(i)
        }
        @view.push_focus(:troop)
        @view.play_animation(:command_menu_window, :out)
        @view.play_animation(:command_info_window, :in)
      when Itefu::Rgss3::Definition::Skill::Scope::FRIEND
        # 味方から選択
        @mask = :dead?
        @view.control(:party).cursor_index = @context.user_index
        @view.push_focus(:party)
        @view.play_animation(:command_menu_window, :out)
      when Itefu::Rgss3::Definition::Skill::Scope::DEAD_FRIEND
        # 味方から選択
        @mask = :alive?
        @view.control(:party).cursor_index = @context.user_index
        @view.push_focus(:party)
        @view.play_animation(:command_menu_window, :out)
      when Itefu::Rgss3::Definition::Skill::Scope::MYSELF
        # 使用者自身
        if party_unit = manager.party_unit
          add_action(party_unit.make_target(@context.user_index))
        end
        start_next_command
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_FRIENDS
        # 全ての味方
        if party_unit = manager.party_unit
          add_action(party_unit.make_target_all)
        end
        start_next_command
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_DEAD_FRIENDS
        # 全ての死んだ味方
        if party_unit = manager.party_unit
          add_action(party_unit.make_target_all_dead)
        end
        start_next_command
      when Itefu::Rgss3::Definition::Skill::Scope::ALL_OPPONENTS
        # 全ての敵
        @view.push_focus(:troop_all)
        @view.play_animation(:command_menu_window, :out)
        @view.play_animation(:command_info_window, :in)
        update_command_info(nil)
      else
        # ランダムまたは対象なし
        count = Itefu::Rgss3::Definition::Skill::Scope.random_count(@reserved_item.scope)
        if 0 < count && troop_unit = manager.troop_unit
          add_action(troop_unit.make_target_random(count))
        end
        start_next_command
      end
    when RPG::EquipItem
      # 装備
      # 味方から選択
      @mask = :dead?
      @view.control(:party).cursor_index = @context.user_index
      @view.push_focus(:party)
      @view.play_animation(:command_menu_window, :out)
    else
      ITEFU_DEBUG_OUTPUT_ERROR "unknown item #{@reserved_item}"
      start_next_command
    end
  end

  # アイテム選択のキャンセル
  def canceled_items(control, cursor_index)
    cancel_reservation
  end

  # アイテム選択の操作
  def operation_items(control, code, *args)
    case code
    when Operation::DECIDE
      if RPG::Skill === @reserved_item
        unless @context.party.status(@context.user_index).skill_usable?(@reserved_item)
          @viewmodel.notice = @message.text(:command_inhibited_skill)
          control.push_focus(:notice_message)
          Sound.play_disabled_se
          return nil
        end
        if @reserved_item.mp_cost > @context.party.mp(@context.user_index)
          @viewmodel.notice = @message.text(:command_nomp)
          control.push_focus(:notice_message)
          Sound.play_disabled_se
          return nil
        end
        if medium_id = @reserved_item.medium_id
          num = @reserved_item.medium_num
          if num > @context.party.number_of_item(medium_id)
            medium_item = Application.database.items[medium_id]
            @viewmodel.notice = format(@message.text(:command_nomedium), item: medium_item.name, count: num)
            control.push_focus(:notice_message)
            Sound.play_disabled_se
            return nil
          end
        end
        if restrictions = @reserved_item.restriction_keys
          restrictions.each do |key|
            if ret = self.send(:"operation_items_#{key}", control, code, *args)
              return nil
            end
          end
        end
      end
    end
    code
  end

  def operation_items_hp(control, code, *args)
    unless @context.party.hp(@context.user_index) < @context.party.mhp(@context.user_index)
      @viewmodel.notice = @message.text(:command_hpexcess)
      control.push_focus(:notice_message)
      Sound.play_disabled_se
      true
    end
  end

  # アイテム選択のカーソルが変わった
  def cursor_items_changed(control, next_index, current_index)
    if next_index
      apply_item_detail(next_index) 
      reserve_action(next_index)
    end
  end

  # 説明文を設定
  def apply_item_detail(item_index)
    item = item_index && item = @viewmodel.items[item_index]
    description = item && item.description || ""

    if @context.detail_opened
      if description.empty?
        # close
        @view.play_animation(:command_detail_window, :out)
        @context.detail_opened = false
      end
    else
      unless description.empty?
        # open
        @view.play_animation(:command_detail_window, :in)
        @context.detail_opened = true
      end
    end
    @viewmodel.description = description
  end

  # アクションリストに予約する
  def reserve_action(item_index)
    action_unit = manager.action_unit

    item = item_index && item = @viewmodel.items[item_index]
    if item
      # 仮押さえする
      icon_index = @context.party.icon_index(@context.user_index)
      if party_unit = manager.party_unit
        actor_unit = party_unit.unit(@context.user_index)
      end
      if actor_unit && actor_unit.action_speed
        speed = actor_unit.action_speed + item.speed
      else
        speed = item.speed
      end
      action_unit.reserve_action(actor_unit, item.item, icon_index, actor_unit.icon_label, item.name, speed) if action_unit
      @reserved_item = item.item
    else
      # 予約を解除する
      action_unit.cancel_reservation if action_unit
      @reserved_item = nil
    end
  end

  # アクションリストの予約を解除する
  def cancel_reservation(cancel_index = nil)
    return unless action_unit = manager.action_unit
    if cancel_index
      if party_unit = manager.party_unit
        actor_unit = party_unit.unit(cancel_index)
        action_unit.cancel_reservation(actor_unit) {|action|
          # 使用するアイテムをキャンセル
          unless RPG::Item === action.item && action.item.consumable.!
            @context.using_items[action.item] -= 1
          end
          true
        } unless actor_unit.auto_action?
      end
    else
      action_unit.cancel_reservation
    end
  end

  # アクションリストに行動を追加する
  def add_action(target)
    return unless action_unit = manager.action_unit
    action_unit.add_action_from_reservation(target)

    # 使用するアイテムを減らす
    unless RPG::Item === @reserved_item && @reserved_item.consumable.!
      @context.using_items[@reserved_item] += 1
    end
  end

  # コマンド選択を開始する
  def start_command(user_index)
    @context.user_index = user_index
    return start_next_command if @context.party.uncontrollable?(user_index)

    activate_player(user_index)
    # 術式があるかどうかでメニューを変える
    actor_unit = manager.party_unit.unit(@context.user_index)
    # @viewmodel.nomagic = actor_unit.has_magic?.!
    # 4人いるのでコマンド位置がずれる
    @viewmodel.apply_user_index(@context.party.commandable_member_size, user_index)
    @view.play_animation(:command_menu_window, :in)
    unless @view.rewind_focus(:command_menu)
      @view.push_focus(:command_menu)
    end
    @view.control(:command_menu).cursor_index = 0
    @view.control(:command_items).scroll_y = 0
  end

  # プレイヤー情報をアクティブにする
  def activate_player(user_index = nil)
    return unless status_unit = manager.status_unit
    if user_index
      # 特定のキャラのコマンド選択中
      status_unit.active_only(user_index)
      manager.party_unit.active_only(user_index)
    else
      # コマンド選択していない
      status_unit.active_all
      manager.party_unit.active_none
    end
  end

  # 次の人のコマンドを選択
  def start_next_command
    next_index = @context.user_index + 1
    if next_index < @context.party.member_size
      # to next user
      start_command(next_index)
    else
      activate_player
      @view.push_focus(:confirm)
      @view.control(:confirm).cursor_index = 0
      if @view.control(:command_menu_window).openness != 0
        @view.play_animation(:command_menu_window, :out)
      end
    end
  end

  # 前の人のコマンドに戻る
  def start_previous_command(start = 1)
    prev_index = @context.user_index - start
    until prev_index == 0 || @context.party.uncontrollable?(prev_index).!
      prev_index -= 1
      cancel_reservation(prev_index)
    end
    if @context.party.uncontrollable?(prev_index)
      start_command(@context.user_index)
    else
      start_command(prev_index)
    end
  end

  # 敵味方選択のキャンセル
  def canceled_target(control, cursor_index)
    @view.play_animation(:command_menu_window, :in)
    if @view.control(:command_info_window).openness != 0
      @view.play_animation(:command_info_window, :out)
    end
  end

  # 敵選択のカーソルが変わった
  def cursor_target_changed(control, next_index, current_index)
    @view.play_animation(:command_info_window, :in)
    update_command_info control.child_at(next_index)
  end

  # 敵情報の内容を更新する
  def update_command_info(target)
    actor_unit = manager.party_unit.unit(@context.user_index)
    if target
      # 個別の対象へ
      enemy_unit = target.enemy_unit
      enemy_status = target.enemy_status
      @viewmodel.info_name = enemy_unit.unique_name
      dmg = enemy_status.mhp - enemy_status.hp
      @viewmodel.info_dmg = dmg
      if Battle::SaveData::SystemData.collection.enemy_known?(enemy_status.enemy_id)
        @viewmodel.info_mhp = enemy_status.mhp
      else
        @viewmodel.info_mhp = 0
      end
      @viewmodel.info_rate = dmg.to_f / enemy_status.mhp

      @viewmodel.info_states = enemy_status.states +
        enemy_status.buffs.map {|k, v| [k, v.size] } + 
        enemy_status.debuffs.map {|k, v| [k, v.size * -1] }
      # 相手の行動の詳細
      action_unit = manager.action_unit
      actions = action_unit.select_actions(enemy_unit).sort_by!(&:speed).reverse!.map do |action|
        info = ViewModel::ActionInfo.new
        info.name = action.action_name.value
        if info.name
          info.elements = Game::Agency.item_elements(enemy_status, action.item)
        else
          info.elements = []
        end
        info.targets = action.target.call.map {|t|
          ViewModel::ActionTarget.new(t.icon_index, Itefu::Utility::Math.clamp(0, 100, Game::Agency.hit_rate(enemy_status, t.status, action.item).to_i))
        }
        info
      end
      if actions.empty?
        # 行動なし
        info = ViewModel::ActionInfo.new
        info.name = manager.lang_message.text(:command_info_noaction)
        info.elements = info.targets = []
        actions << info
      end
      @viewmodel.info_actions = actions
=begin
      # 行動一回のみ仕様のころの処理
      if action = action_unit.find_action(enemy_unit)
        if @viewmodel.info_action_name = action.action_name.value
          @viewmodel.info_action_elements = Game::Agency.item_elements(enemy_status, action.item)
        else
          @viewmodel.info_action_elements = []
        end
        @viewmodel.info_action_target.modify action.target.call.map {|t|
          ViewModel::ActionTarget.new(t.icon_index, Itefu::Utility::Math.clamp(0, 100, Game::Agency.hit_rate(enemy_status, t.status, action.item).to_i))
        }
      else
        # 行動なし
        @viewmodel.info_action_name = manager.lang_message.text(:command_info_noaction)
        @viewmodel.info_action_elements = []
        @viewmodel.info_action_target = []
      end
=end
      @viewmodel.info_hits = []
      @viewmodel.info_hit = Itefu::Utility::Math.clamp(0, 100, Game::Agency.hit_rate(actor_unit.status, enemy_unit.status, @reserved_item).to_i)
    else
      # 全体を対象
      @viewmodel.info_name = @message.text(:command_info_hit_all)
      @viewmodel.info_dmg = ""
      @viewmodel.info_rate = 0
      @viewmodel.info_states = []
      @viewmodel.info_mhp = nil
      @viewmodel.info_actions = []
      # @viewmodel.info_action_name = nil
      # @viewmodel.info_action_target = []
      # @viewmodel.info_action_elements = []
      if troop_unit = manager.troop_unit
        @viewmodel.info_hits = troop_unit.units.select {|unit|
          unit.available?
        }.map {|unit|
          ViewModel::TargetInfo.new(unit.icon_index, unit.enemy_label, Itefu::Utility::Math.clamp(0, 100, Game::Agency.hit_rate(actor_unit.status, unit.status, @reserved_item).to_i))
        }
      else
        @viewmodel.info_hits = []
      end
      @viewmodel.info_hit = nil
    end
  end

  # 敵選択の決定
  def decided_troop(control, cursor_index, x, y)
    target = control.child_at(cursor_index)
    add_action(target.enemy_unit.make_target_surely(manager.troop_unit))
    @view.play_animation(:command_info_window, :out)
    start_next_command
  end

  # 敵選択の決定
  def decided_troop_all(control, cursor_index, x, y)
    if troop_unit = manager.troop_unit
      add_action(troop_unit.make_target_all)
    end
    @view.play_animation(:command_info_window, :out)
    start_next_command
  end

  # 味方選択の操作
  def operation_party(control, code, *args)
    case code
    when Operation::DECIDE
      target = control.child_at(control.cursor_index)
      if target.actor_unit.status.send(@mask)
        Sound.play_disabled_se
        nil
      else
        code
      end
    else
      code
    end
  end

  # 味方選択の決定
  def decided_party(control, cursor_index, x, y)
    target = control.child_at(cursor_index)
    add_action(target.actor_unit.make_target_friendly)
    start_next_command
  end

  # 確認ウィンドウでの決定
  def decided_confirm(control, cursor_index, x, y)
    if cursor_index != 0
      start_previous_command(0)
      cancel_reservation(@context.user_index)
    else
      @context.using_items.clear
      change_unit_state(Battle::Unit::State::COMMANDED)
      @view.clear_focus
    end
  end

  # 確認ウィンドウの操作
  def operation_confirm(control, code, *args)
    case code
    when Operation::CANCEL
      start_previous_command(0)
      cancel_reservation(@context.user_index)
      nil
    else
      code
    end
  end

  def on_unit_state_changed(old)
    case unit_state
    when Battle::Unit::State::COMMANDING
      # ステート情報を更新する
      db_states = @manager.database.states
      state_details = []
      manager.party_unit.units.each do |actor_unit|
        status = actor_unit.status
        first = true
        status.state_data.each do |state_id, state_data|
          next unless state = db_states[state_id]
          next if state.party_state?
          next if state.detail_name.empty?
          state_details << ViewModel::StateDetail.new(state_id, state_data.turn_count, first ? actor_unit.icon_index : nil)
          first = false
        end
        if first
          state_details << ViewModel::StateDetail.new(nil, nil, actor_unit.icon_index)
          state_details << nil
        end
      end
      @viewmodel.state_details.modify state_details
      @viewmodel.stated = state_details.any? {|data|
        # 戦闘不能と防御以外のステートがあれば詳細ウィンドウを出す
        next false unless data && data.id && data.id != 1
        next false unless state = db_states[data.id]
        # 「防御」のみが指定されているステートかチェック
        features = state.features
        next true if features.size != 1
        feature = features.first
        # 防御
        next false if feature.code == Itefu::Rgss3::Definition::Feature::Code::SPECIAL_FLAG && feature.data_id == Itefu::Rgss3::Definition::Feature::SpecialFlag::GUARD
        # 除外条件に当てはらないステートだった
        true
      }

    when Battle::Unit::State::FINISHING
      if @view.control(:command_menu_window).openness != 0
        @view.play_animation(:command_menu_window, :out)
      end
    end
  end

  # --------------------------------------------------
  # ViewModel

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :actor_rindex
    attr_observable :items
    # attr_observable :nomagic
    attr_observable :description
    attr_observable :info_name, :info_dmg, :info_mhp, :info_rate
    # attr_observable :info_action_name, :info_action_target, :info_action_elements
    attr_observable :info_actions
    attr_observable :info_states
    attr_observable :info_hits
    attr_observable :info_hit
    attr_observable :state_details
    attr_observable :stated
    attr_observable :notice

    UsingItem = Struct.new(:icon_index, :name, :short_name, :cost, :description, :speed, :item)
    TargetInfo = Struct.new(:icon_index, :label, :hit_rate)
    ActionTarget = Struct.new(:icon_index, :hit_rate)
    ActionInfo = Struct.new(:name, :targets, :elements)
    StateDetail = Struct.new(:id, :turn_count, :icon_index)


    def initialize(viewport)
      self.viewport = viewport
      self.actor_rindex = 0
      self.items = []
      # self.nomagic = true
      self.description = ""
      self.info_name = ""
      self.info_dmg = self.info_mhp = self.info_rate = 0
      # self.info_action_name = ""
      # self.info_action_target = []
      # self.info_action_elements = []
      self.info_actions = []
      self.info_states = []
      self.info_hits = []
      self.info_hit = nil
      self.state_details = []
      self.stated = false
      self.notice = ""
      @detail_opened = false
    end

    def apply_user_index(member_size, user_index)
      self.actor_rindex = member_size - 1 - user_index
    end
  end

end


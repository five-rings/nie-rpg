=begin
  フィールドメニューのスキル使用画面
=end
class Scene::Game::Menu::Skill < Scene::Game::Base
  include Layout::View

  def on_initialize(message, index = nil)
    @message = message
    @viewmodel = ViewModel.new(message)
    load_layout("menu/skill", @viewmodel)

    # キャラ選択
    control(:charamenu).tap do |control|
      control.add_callback(:decided, method(:on_charamenu_decided))
      control.add_callback(:cursor_changed, method(:on_charamenu_cursor_changed))
      if index
        control.cursor_index = index
        control.scroll_to_child(index)
      end
    end

    # スキル一覧
    control(:skilllist).tap do |control|
      control.focused = method(:on_skilllist_focused)
      control.add_callback(:cursor_changed, method(:on_skilllist_cursor_changed))
      control.add_callback(:decided, method(:on_skilllist_decided))
      control.add_callback(:canceled, method(:on_skilllist_canceled))
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
    update_skilllist(index || 0)
    enter
  end

  def on_finalize
    Application.focus.pop
    finalize_layout
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


  # --------------------------------------------------
  # キャラ選択

  def on_charamenu_decided(control, index, x, y)
    actor_id = Application.savedata_game.party.members[index]
    @skill_user = Application.savedata_game.actors[actor_id]

    c = push_focus(:skilllist)
    # c.cursor_index = 0
  end

  def on_charamenu_cursor_changed(control, next_index, current_index)
    if next_index
      update_skilllist(next_index)
    end
    if current_index && next_index != current_index
      c = control(:skilllist)
      c.scroll_y = 0
      c.cursor_index = 0
    end
  end

  def update_skilllist(index)
    db_skills = Application.database.skills
    actor_id = Application.savedata_game.party.members[index]
    if actor = Application.savedata_game.actors[actor_id]
      skills = actor.skills.map {|skill_id| db_skills[skill_id] }
      skills.sort!
      skills << nil if skills.size % 2 != 0 && skills.size > 1
      @viewmodel.skills.modify skills
    else
      @viewmodel.skills.modify []
    end
  end

  # --------------------------------------------------
  # スキル一覧

  def on_skilllist_focused(control)
    update_skill_description(0)
  end

  def on_skilllist_cursor_changed(control, next_index, current_index)
    update_skill_description(next_index) if next_index
  end

  def update_skill_description(index)
    if skill = @viewmodel.skills[index]
      @viewmodel.description = skill.description
    else
      @viewmodel.description = ""
    end
  end

  def on_skilllist_decided(control, index, x, y)
    return unless skill = @viewmodel.skills[index]

    if RPG::UsableItem === skill && Itefu::Rgss3::Definition::Skill::Occasion.usable_in_fieldmenu?(skill.occasion)
      @target_skill = skill
      setup_dialog_to_select_chara
      if Itefu::Rgss3::Definition::Skill::Scope.to_singular?(skill.scope)
        c = control.push_focus(:dialog_chara_list)
        c.cursor_index = 0
      else
        control.push_focus(:dialog_chara_all)
      end
    else
      # フィールドでは使えないスキル
      if Itefu::Rgss3::Definition::Skill::Occasion.usable_in_battle?(skill.occasion)
        @viewmodel.notice = @message.text(:skill_for_battle)
      else
        if skill.mp_cost > 0
          @viewmodel.notice = @message.text(:skill_nouse)
        else
          @viewmodel.notice = @message.text(:skill_passive)
        end
      end
      control.push_focus(:notice_message)
    end
  end

  def on_skilllist_canceled(control, index)
    if Application.savedata_game.party.members.size <= 1
      # メンバーを選ばない場合
      pop_focus
    else
      @viewmodel.description = ""
    end
  end

  # --------------------------------------------------
  # 使う

  def setup_dialog_to_select_chara
    @viewmodel.dialog_chara.message = sprintf(@message.text(:skill_use), @target_skill.icon_index, @target_skill.name, @target_skill.mp_cost)

    actors = Application.savedata_game.actors
    targets = Application.savedata_game.party.members.map {|actor_id|
      actor = actors[actor_id]
      actor && actor.alive? && Layout::ViewModel::Dialog::Chara.actor_data(actor) || nil
    }
    targets.compact!
    @target_actors = targets
    @viewmodel.dialog_chara.actors.modify targets
  end

  def skill_usable?
    @target_skill && @skill_user && @skill_user.mp >= @target_skill.mp_cost
  end

  def on_chara_list_decided(control, index, x, y)
    unless skill_usable?
      @viewmodel.notice = @message.text(:skill_nomp)
      control.push_focus(:notice_message)
      Sound.play_disabled_se
      return
    end
    use_item(@target_skill, @skill_user, @target_actors[index, 1])
    return clear_focus if exit_code
  end

  def on_chara_all_decided(control, index, x, y)
    unless skill_usable?
      @viewmodel.notice = @message.text(:skill_nomp)
      control.push_focus(:notice_message)
      Sound.play_disabled_se
      return
    end
    use_item(@target_skill, @skill_user, @target_actors)
    return clear_focus if exit_code
  end

  def use_item(item, user, targets)
    Itefu::Sound.play_use_item_se
    actors = Application.savedata_game.actors
    targets.each do |actor_data|
      if actor = actors[actor_data.actor_id.value]
        @agent ||= Game::Agency::Damage.new
        @agent.apply_item(user, actor, item)
      end
    end

    user.add_mp(-item.mp_cost)
    @viewmodel.dialog_chara.actors.value.each(&:update)
    @viewmodel.charamenu.value.each(&:update)

    if check_if_common_event(item)
      return exit(item)
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
    attr_observable :charamenu
    attr_observable :skills
    attr_observable :description
    attr_observable :notice
    attr_reader :dialog_chara

    def initialize(msg)
      self.charamenu = Application.savedata_game.party.members.map {|actor_id|
        vm = Layout::ViewModel::CharaMenu.new
        vm.copy_from_actor Application.savedata_game.actors[actor_id]
        vm
      }
      self.skills = []
      self.description = ""
      self.notice = ""
      @dialog_chara = Layout::ViewModel::Dialog::Chara.new
    end
  end

end

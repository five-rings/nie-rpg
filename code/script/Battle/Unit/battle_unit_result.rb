=begin
=end
class Battle::Unit::Result < Battle::Unit::Base
  include Itefu::Focus::Focusable
  include Itefu::Utility::State::Context
  def default_priority; Battle::Unit::Priority::RESULT; end
  def closed?; @closed; end

  def on_initialize(viewport)
    @view = manager
    @viewmodel = ViewModel.new(viewport)
  end

  def on_update
    update_state
  end

  def on_draw
    draw_state
  end

  def open(booty)
    return if @booty
    @booty = booty
    party = manager.party
    cmoney = Battle::SaveData::GameData.gold_double? ? 2 : 1

    update_items(booty.items)
    update_money(booty.amount_of_money * cmoney)

    @viewmodel.exp_earned = booty.amount_of_exp
    @viewmodel.money_earned = booty.amount_of_money * cmoney

    @viewmodel.items = @booty.items
    @viewmodel.actors.change(true) do |actors|
      party.member_size.times do |i|
        actors << ViewModel::Member.new.tap {|data|
          party.copy_actor_data(i, data, :face_name, :face_index, :job_name, :level, :exp, :exp_next)
        }
      end
    end

    @view.add_layout(:base, "battle/result", @viewmodel)

    setup_actor_data

    manager.focus.push(self)
    change_state(State::Opening)
  end

  def setup_actor_data
    party = manager.party
    @actor_data = manager.party.member_size.times.map do |index|
      next nil unless status = party.status(index)
      { level: status.level, job_name: status.job_name, skills: status.skills_raw.clone }
    end
  end

  def on_operation_instructed(code, *args)
    if code != Itefu::Layout::Definition::Operation::MOVE_POSITION
      @operated = true
    end
  end

  def on_state_opening_attach
    @anime = @view.play_animation(:result_window, :in)
    @operated = false
  end

  def on_state_opening_update
    return if @anime.playing?
    change_state(Itefu::Utility::State::Wait, 30, State::Exp)
  end

  def on_state_exp_attach
    @anime = animation_earning_exp
    @view.play_raw_animation(@anime, @anime)
    if @viewmodel.exp_earned > 0
      manager.sound.play_se("Resonance", 80, 300) if manager.sound
    end
  end

  def on_state_exp_update
    if @operated
      if @anime.playing?
        @anime.finish
        @operated = false
      else
        change_state(State::Notice)
      end
    end
  end

  def on_state_exp_detach
    @notice_shown = false
  end

  def on_state_notice_attach
    @notice_index ||= 0
    return change_state(State::Close) unless @notice_index < @actor_data.size

    data = @actor_data[@notice_index]
    return change_state(State::Notice) unless data

    status = manager.party.status(@notice_index)
    return change_state(State::Notice) unless status
    return change_state(State::Notice) unless status.level > data[:level]

    # New Skills
    @notice_skills = status.skill_diffs(data[:skills])

    # New Job Name
    actor = manager.party.status(@notice_index)
    if newjobname = actor.job.highjob_name(status.level, data[:level])
      if fmt_levelup_newjob = Application.language.message(:game, :level_up_newjob)
        @notice_skills.unshift(sprintf(fmt_levelup_newjob, data[:job_name], newjobname, data[:level], status.level))
      end
    elsif @notice_skills.empty?.!
      # 見出しを付ける
      if fmt_levelup = Application.language.message(:game, :level_up)
        @notice_skills.unshift(sprintf(fmt_levelup, actor.job_name, data[:level], status.level))
      end
    end

    unless assign_notice_message
      return change_state(State::Notice) 
    end
    @notice_shown = true
    manager.sound.play_se("Item3", 90, 100) if manager.sound
  end

  def assign_notice_message
    return if @notice_skills.empty?
    return unless fmt_skill = Application.language.message(:game, :learnt_skill_indent)

    actor = manager.party.status(@notice_index)
    message = ""
    count = 0
    while count < 4
      case sid = @notice_skills.shift
      when String
        message << sid
        message << Itefu::Rgss3::Definition::MessageFormat::NEW_LINE
        count += sid.count(Itefu::Rgss3::Definition::MessageFormat::NEW_LINE)
      when Integer
        message << sprintf(fmt_skill, sid)
        message << Itefu::Rgss3::Definition::MessageFormat::NEW_LINE
      end
      count += 1
    end

    unless message.empty?
      manager.message_unit.show(message, actor.face_name, actor.face_index, 0, 2)
      true
    end
  end

  def on_state_notice_update
    return if manager.message_unit.showing?

    unless assign_notice_message
      change_state(State::Notice) if manager.message_unit.window_closed?
    end
  end

  def on_state_notice_detach
    @notice_index += 1
  end

  def on_state_close_attach
    unless @notice_shown
      manager.sound.play_ok_se if manager.sound
    end
    @anime = @view.play_animation(:result_window, :out)
  end

  def on_state_close_update
    return if @anime.playing?
    change_state(Itefu::Utility::State::DoNothing)
  end

  def on_state_close_detach
    manager.focus.pop
    @closed = true
  end


  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_accessor :exp_earned
    attr_accessor :money_earned
    attr_observable :actors, :items

    class Member
      include Itefu::Layout::ViewModel
      attr_accessor :face_name, :face_index, :job_name
      attr_observable :level
      attr_observable :exp, :exp_next
    end

    def initialize(viewport)
      self.viewport = viewport
      self.actors = []
      self.items = [nil]
    end
  end

private

  def animation_earning_exp
    animations = Itefu::Animation::Composite.new
    return animations unless @viewmodel.exp_earned > 0

    proc_update = proc {|anime|
      index = anime.context[:index]
      status = manager.party.status(index)
      exp_to_add = Itefu::Utility::Math.clamp(1, Itefu::Utility::Math.max(1, status.exp_next / 30), anime.context[:exp_diff])

      if update_exp(index, exp_to_add)
        # level up
        manager.sound.play_se("Item3", 90, 125) if manager.sound
      end
      anime.context[:exp_earned] -= exp_to_add
      if anime.context[:exp_earned] <= 0
        anime.finish
      end
    }
    proc_finish = proc {|anime|
      # スキップされたときのための処理
      if anime.context[:exp_earned] > 0
        index = anime.context[:index]
        if update_exp(index, anime.context[:exp_earned])
          manager.sound.play_se("Item3", 90, 125) if manager.sound
        end
      end
    }

    manager.party.member_size.times do |i|
      status = manager.party.status(i)
      animations.add_animation(Itefu::Animation::Base).with_context({
        :exp_earned => (@viewmodel.exp_earned * status.exp_earning_rate).to_i,
        :exp_diff => @viewmodel.exp_earned / 30,
        :index => i,
      }).updater(&proc_update).finisher(&proc_finish)
    end
    animations
  end

  def update_exp(index, exp_to_add)
    return false unless status = manager.party.status(index)
    old_level = status.level
    status.add_exp(exp_to_add)
    @viewmodel.actors[index].level = status.level
    @viewmodel.actors[index].exp = status.exp
    @viewmodel.actors[index].exp_next = status.exp_next
    if old_level != status.level
      status.recover_by_leveling_up(old_level)
      true
    else
      false
    end
  end

  def update_items(items)
    inv = manager.party
    items.each do |item|
      inv.add_item(item)
    end
  end

  def update_money(money)
    manager.party.add_money(money)
  end

  module State
    module Opening
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end

    module Exp
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end

    module Notice
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end

    module Close
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end
  end

end


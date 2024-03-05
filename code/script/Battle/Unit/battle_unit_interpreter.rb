=begin
  戦闘中のイベント実行
=end
class Battle::Unit::Interpreter < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::INTERPRETER; end
  # include Itefu::Utility::Callback

  def running?
    @interpreter && @interpreter.event_interpreter_running?
  end

  def on_initialize
    @events_processed = {}
    @reserves = []
  end

  def on_finalize
    @interpreter = nil
    @reserves.clear
  end

  def on_update
    if @interpreter
      @interpreter.update_event_interpreter
      unless @interpreter.event_interpreter_running?
        @interpreter = nil
      end
    end
  end

  # @param [Boolean|NilClass] turn_end nilで戦闘終了時
  def trigger_event(turn_end)
    pages = manager.troop.pages
    if turn_end.nil?
      page_index = find_page_index_for_ending_by_condition(pages)
      context = { result: manager.result.outcome }
    else
      page_index = find_page_index_by_condition(pages, turn_end)
      context = nil
    end
    page = page_index && pages[page_index]

    if page
      if page.span != Itefu::Rgss3::Definition::Event::Span::MOMENT
        @events_processed[page_index] = page.span
      end
      start_battle_event(manager.troop.troop_id, page_index, page.list, context)
    end
  end

  def start_battle_event(event_id, page_index, commands, context = nil)
    if running?
      return reserve_event(event_id, page_index, commands, context)
    end
    @interpreter = Event::Interpreter::Battle.new
    @interpreter.battle_manager = manager
    @interpreter.start_event(manager.troop.troop_id, event_id, page_index, commands, context, method(:on_finished))
    # execute_callback(:start_event, key, interpreter)
    @interpreter
  end

  def reserve_event(*args)
    @reserves << args
  end

  def reset_turn_event
    @events_processed.each do |page_index, span|
      if span != Itefu::Rgss3::Definition::Event::Span::BATTLE
        @events_processed[page_index] = false
      end
    end
  end

  # 条件に合うイベントページを探す
  def find_page_index_by_condition(pages, turn_end)
    pages.index.with_index {|page, index|
      next false if @events_processed[index]
      c = page.condition
      ret = false

      if c.turn_ending
        next false unless turn_end
        # 「ターン終了時」の指定だけでは有効にしない
        # ret = true
      else
        # ターン終了時には「ターン終了時」を指定していなくても呼ばれ得る
        # next false if turn_end
        # ret = true # it needs more conditions if turn_end is off
      end

      if c.turn_valid
        turn = manager.turn_count
        if c.turn_b == 0
          next false unless turn == c.turn_a
        else
          next false if turn == 0
          t = (turn - c.turn_a)
          next false unless t >= 0 && t % c.turn_b == 0
        end
        ret = true
      end

      if c.enemy_valid
        next false unless enemy = manager.troop.enemies[c.enemy_index]
        next false unless enemy.hp <= enemy.mhp * c.enemy_hp / 100
        ret = true
      end

      if c.actor_valid
        return false unless party = manager.party
        return false unless actor_index = party.actor_index(c.actor_id)
        next false unless party.hp(actor_index) <= party.mhp(actor_index) * c.actor_hp / 100
        ret = true
      end

      if c.switch_valid
        return unless Battle::SaveData.switch(c.switch_id)
        ret = true
      end

      ret
    }
  end

  # 戦闘終了時に実行できるイベントページを探す
  def find_page_index_for_ending_by_condition(pages)
    pages.index.with_index {|page, index|
      c = page.condition

      # 「ターン終了時」のみがオンのものを戦闘終了時用とみなす
      next false unless c.turn_ending
      next false if c.turn_valid
      next false if c.enemy_valid
      next false if c.actor_valid
      next false if c.switch_valid

      true
    }
  end


private

  def on_finished(interpreter, status)
    if args = @reserves.shift
      start_battle_event(*args)
    end
  end

end


=begin
  イベント実行器のアプリ実装  
=end
class Map::Unit::Interpreter < Map::Unit::Base
  def default_priority; Map::Unit::Priority::INTERPRETER; end
  include Itefu::Utility::Callback
  
  def on_suspend
    @interpreters.each_with_object({}) {|(k,v), m|
      m[k] = v.event_status if v.event_interpreter_running?
    }
  end
  
  def on_resume(context)
    @interpreters ||= {}
    context.each do |key, status|
      interpreter = @interpreters[key] ||= create_new_interpreter(status.current_map_id)
      interpreter.resume_event(status, method(:on_finished))
    end
  end
  
  def running?
    return false unless interpreter = @interpreters[:main]
    interpreter.event_interpreter_running?
  end
  
  def on_initialize
    @interpreters ||= {}
  end
  
  def on_finalize
    @interpreters.clear
  end

  def on_unit_state_changed(old_state)
    case @unit_state
    when State::STOPPED
      # マップ移動時は並行イベントを終了する
      # 残りのコマンドで前のマップのオブジェクトにアクセスするかもしれないので最後まで実行するのでなく即終了する
      @interpreters.keep_if {|k,v| k == :main }
    end
  end
  
  def on_update
    return unless state_opened?
    @interpreters.each_value(&:update_event_interpreter)
    @interpreters.keep_if {|k,v| v.event_interpreter_running? }
  end
  
  # 非並列イベントを実行する
  def start_main_event(map_id, event_id, page_index, commands, context = nil)
    if interpreter = start_event(:main, map_id, event_id, page_index, commands, context)
      interpreter.event_status.data[:key] = :main
    end
    interpreter
  end
  
  # 並列イベントを実行する
  def start_parallel_event(map_id, event_id, page_index, commands, context = nil)
    start_event(event_key(map_id, event_id, page_index), map_id, event_id, page_index, commands, context)
  end


private

  def event_key(*args); args; end

  # イベントを実行する
  def start_event(key, map_id, event_id, page_index, commands, context)
    return if @interpreters.has_key?(key)
    return unless commands
    interpreter = create_new_interpreter(map_id)
    interpreter.start_event(map_id, event_id, page_index, commands, context, method(:on_finished))
    execute_callback(:start_event, key, interpreter)
    # ITEFU_DEBUG_OUTPUT_NOTICE "parallel #{interpreter.event_status.inspect}"
    @interpreters[key] = interpreter
  end

  def create_new_interpreter(map_id)
    Event::Interpreter::Map.new.tap {|interpreter|
      interpreter.map_manager = manager
      interpreter.map_instance = manager.find_instance(map_id)
    }
  end
  
  def on_finished(interpreter, status)
    execute_callback(:finish_event, interpreter, status)
    return unless status.data[:key] == :main

    if status.event_id && instance = manager.find_instance(status.map_id)
      event = instance.event(status.event_id)
      event.finish_event_command(interpreter, status) if event
    end
    manager.player_unit.finish_event_command(interpreter, status)
  end
  
end

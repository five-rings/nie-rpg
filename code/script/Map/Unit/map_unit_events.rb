=begin
=end
class Map::Unit::Events < Map::Unit::Composite
  def default_priority; Map::Unit::Priority::EVENTS; end
  def map_structure; @map_instance; end
  attr_reader :map_instance

  module SpaceDivision; end

  module AlwaysActive
    # SpaceDivisionを使用する際に個々のEventのみ常時処理したい場合に使用
    def always_active?; true; end
  end

  # イベントを空間分割して部分的に処理するようにする
  def use_space_division
    unless SpaceDivision === self
      self.extend SpaceDivision
    end
  end
 
  # attach時にEventは何もしないので無駄なイテレーションを省く
  def send_attached(manager); end
  # detach時にEventは何もしないので無駄なイテレーションを省く
  def send_detached; end
 

  def on_initialize
    @map_instance = @manager
  end

  def on_update
    update_event_page
    evoke_common_events
    evoke_auto_events
  end

  def update_scroll(ox, oy)
    # 
    units.each do |unit_event|
      unit_event.update_scroll(ox, oy)
    end
  end

  def register_event(event_id, cell_x, cell_y, event)
    vp_map = map_instance.map_viewport
    add_unit(Map::Unit::Event, event, vp_map)
    # unitをcompositeに追加しておけばresumeは子のものも呼ばれる
  end

  def unregister_event(event_id, cell_x, cell_y)
    detach_units_if do |unit|
      unit.event_id == event_id
    end
  end

  def move_registered_event(event_id, event, cell_x, cell_y, old_x, old_y)
  end

  def find_event
    r = units.find {|unit|
      yield(unit)
    }
    return r if r
  end

  module SpaceDivision
    def on_resume_signaled(context)
      # イベント用のresuming contextを割り当てておく
      @map_spaces.values.each do |space|
        space.each do |event_id, event|
          next unless c = context[event_id]
          event.resuming_context = c
          # デフォルト位置と違ったら移動させる
          cx = c[:@cell_x]
          cy = c[:@cell_y]
          if cx && cy && (event.x != cx || event.y != cy)
            premove_registered_event(event_id, event, cx, cy, event.x, event.y)
          end
        end
      end
      super
    end

    def on_suspend_signaled(context)
      # 割り当てられなかったイベントのresuming_contextも保存する
      @map_spaces.each_value do |space|
        space.each do |event_id, event|
          if Map::Unit::Event === event
            event.suspend(context)
          else
            if c = event.resuming_context
              context[event_id] = c
            end
          end
        end
      end
      super
    end

    def self.extended(obj)
      obj.setup_space
    end

    def on_initialize
      super
      setup_space
    end

    def setup_space
      # 部分更新用にマップを分割した空間
      @map_spaces = Hash.new {|h,k| h[k] = {} }
      # 更新対象にするmap_spaceのindex
      @map_space_indices = []
      @old_space_indices = []
    end

    def on_finalize
      super
      clear_registered_events
    end

    def update_scroll(ox, oy)
      # 更新対象になる箇所を更新
      @map_space_indices, @old_space_indices = @old_space_indices, @map_space_indices
      @map_space_indices.clear
      map_structure.map_space_indices(ox, oy, @map_space_indices)

      # 更新する対象のイベントを変更
      detach_events(@old_space_indices - @map_space_indices)
      attach_events(@map_space_indices - @old_space_indices)

      super
    end

    def clear_registered_events
      @map_spaces.each_value do |space|
        space.each_value do |event|
          if Map::Unit::Event === event
            event.finalize
          end
        end
      end
      @map_spaces.clear
    end
    
    def register_event(event_id, cell_x, cell_y, event)
      if /^.?_/ === event.name
        unit = super
        unit.extend AlwaysActive
      else
        index = map_structure.map_space_index(cell_x, cell_y)
        @map_spaces[index][event_id] = event
      end
    end
    
    def unregister_event(event_id, cell_x, cell_y)
      index = map_structure.map_space_index(cell_x, cell_y)
      @map_spaces[index].delete(event_id)
    end

    # resumingなどでマップ開始前に移動する
    def premove_registered_event(event_id, event, cell_x, cell_y, old_x, old_y)
      old_index = map_structure.map_space_index(old_x, old_y) if old_x && old_y
      index = map_structure.map_space_index(cell_x, cell_y)
      if old_index != index
        @map_spaces[old_index].delete(event_id)
        @map_spaces[index][event_id] = event
      end
    end
    
    # イベントの移動などマップ動作中の移動を処理する
    def move_registered_event(event_id, event, cell_x, cell_y, old_x, old_y)
      if event.always_active?
        super
      else
        old_index = map_structure.map_space_index(old_x, old_y) if old_x && old_y
        index = map_structure.map_space_index(cell_x, cell_y)
        if old_index != index
          @map_spaces[old_index].delete(event_id) if old_index
        end
        unless @map_space_indices.include?(index)
          @map_spaces[index][event_id] = event
          detach_unit(event)
        end
      end
    end

    def find_event
      super
      @map_spaces.find {|index, events|
        events.find {|event_id, event|
          yield(event)
        }
      }
    end

private

    # diffsに存在するイベントを管理対象から外す
    def detach_events(diffs)
      detach_units_if do |unit|
        next false if unit.always_active?
        index = map_structure.map_space_index(unit.cell_x, unit.cell_y)
        if diffs.include?(index)
          @map_spaces[index][unit.event_id] = unit
          true
        end
      end
    end
    
    # diffsに待機しているイベントを管理対象に入れる
    def attach_events(diffs)
      vp_map = map_instance.map_viewport
      lazy_sort {
        diffs.each do |index|
          @map_spaces[index].each do |event_id, event|
            if Map::Unit::Event === event
              attach_unit(event)
            else
              unit = add_unit(Map::Unit::Event, event, vp_map)
              c = event.resuming_context
              if c
                unit.on_resume(c)
                event.resuming_context = nil
              end
            end
          end
          @map_spaces[index].clear
        end
      }
    end

  end

private
  def create_new_unit(klass, *args, &block)
    klass.new(@map_instance, *args, &block)
  end


private
  def interpreter; map_instance.event_interpreter; end
  
  def update_event_page
    units.each(&:fetch_event_page)
  end

  # コモンイベントを起動する
  def evoke_common_events
    common_events = map_instance.manager.database.common_events
    common_events.each do |common_event|
      next unless common_event && Map::SaveData.switch(common_event.switch_id)
      case
      when common_event.autorun?
        interpreter.start_main_event(map_instance.map_id, nil, common_event.id, common_event.list)
      when common_event.parallel?
        interpreter.start_parallel_event(map_instance.map_id, nil, common_event.id, common_event.list)
      end
    end
  end
  
  # 自動／並列イベントを起動する
  def evoke_auto_events
    units.each do |unit|
      next unless page = unit.current_page
      case page.trigger
      when Itefu::Rgss3::Definition::Event::Trigger::AUTO_RUN
        interpreter.start_main_event(map_instance.map_id, unit.event_id, unit.current_page_index, page.list)
      when Itefu::Rgss3::Definition::Event::Trigger::PARALLEL
        interpreter.start_parallel_event(map_instance.map_id, unit.event_id, unit.current_page_index, page.list)
      end
    end
  end

end

=begin  
  Map::Managerの部分実装
  入力関連の処理
=end
class Map::Manager
  COUNT_AS_DOUBLE_CLICK = 20 

  def assign_input(input)
    @input = input
  end
  
  def setup_input
    player_unit.add_callback(:moved, method(:on_player_moved))
    player_unit.add_callback(:unmoved, method(:on_player_unmoved))
    interpreter_unit.add_callback(:start_event, method(:on_start_event))
    interpreter_unit.add_callback(:finish_event, method(:on_finish_event))
    @move_by_click = []
    @move_input_count = 0   # このカウントが0のときのみ移動を受け付ける
    @dclick_count = 0
  end

  def update_input
    @dir_to_move = nil if @dir_to_move == @dir_moving
    @sneaking -= 1 if @sneaking && @sneaking > 0
    @dclick_count -= 1 if @dclick_count > 0
    @input.call(self, inputable?) if @input
    if inputable? && @move_input_count > 0
      @move_input_count -= 1
    end

    # to open guide automatically
    ui_unit.set_guide_auto_open(
      inputable?,
      Map::SaveData::GameData.system.embodied
    )

    # move by mouse click
    player = player_unit
    unless player.moving?
      if dir = @move_by_click.shift
        @dir_moving = dir
        player.move(dir)
      else
        player.dash(false) unless interpreter_unit.running?
      end
    end
  end
  
  def inputable?
    running? &&
    state == State::Main && 
    interpreter_unit.running?.! && 
    @view.focus.empty?
  end
  
  def reset_input(keep = false)
    ui_unit.reset_guide
    if keep
      @keeped_move = @move_by_click
      @keep_last_clicked = @pos_last_clicked
      @move_by_click = []
    else
      @move_by_click.clear
    end
    @pos_last_clicked = nil
    pointer_unit.set_cursor_off
  end
  
  def operate_decide
    return unless inputable?
    return if player_unit.moving?
    player_unit.trigger_event
    reset_input
  end
  
  def operate_mouse_move(x, y)
    return unless inputable?
    if x < 0 || y < 0 || x >= Graphics.width || y >= Graphics.height
      # カーソルをオフ
      pointer_unit.set_cursor_off
    elsif ui_unit.update_cursor(x, y)
      pointer_unit.set_cursor_off
    else
      # 前にキーボード操作をしてからマウス操作をしていたらカーソルをオン
      pointer_unit.update_cursor(x, y)
    end
  end
  
  def operate_click(x, y)
    return unless inputable?
    @pos_last_clicked = nil
    x = Itefu::Utility::Math.clamp(0, Graphics.width, x)
    y = Itefu::Utility::Math.clamp(0, Graphics.height, y)
    node = ui_unit.operate_click(x, y)
    case node
    when Map::Unit::Ui::Guide::SceneGraph::Icon
      Sound.play_decide_se
      quit(node.action) if node.action
    when Itefu::SceneGraph::Base
    else
      operate_move_by_click(x, y)
    end
  end

  def operate_clicking(x, y)
    return unless @pos_last_clicked
    return unless @move_by_click.empty?
    # クリック移動後にクリックしっぱなしの場合追加で移動する
    mi = active_instance      # map_instance
    tm = mi.tilemap.tilemap   # tilemap
    cx = mi.normalized_cell_x((x + tm.ox) / mi.cell_size)
    cy = mi.normalized_cell_y((y + tm.oy) / mi.cell_size)
    if @pos_last_clicked[0] != cx || @pos_last_clicked[1] != cy
      @dclick_count = 0
      # operate_move_by_click(x, y, *@pos_last_clicked) # 現在のパスの終端に追加する
      operate_move_by_click(x, y) # パスを計算し直す
    end
  end
  
  def operate_sneak(sneaking)
    return unless inputable?
    player_unit.sneak(sneaking)
    @sneaking = sneaking && 0
  end

  def operate_dash_on
    return unless inputable?
    if (ai = active_instance) && ai.map_data.disable_dashing.!
      player_unit.dash(true)
    end
  end

  def player_dashing?
    player_unit.dashing?
  end
  
  def operate_move(dir)
    return unless inputable?
    if @move_input_count > 0
      @move_input_count = 2
      return
    end

    player = player_unit
    if player.moving?
      @dir_to_move = dir
    else
      if @sneaking
        if @sneaking <= 0
          if dir != player.direction
            player.turn(dir)
          else
            @dir_moving = dir
            player.move(dir)
          end
        end
        @sneaking = 2
      else
        @dir_moving = dir
        player.move(dir)
      end
    end
    reset_input
  end
  
  def on_player_moved(player, warp)
    @unmoved_processed = false
    return unless inputable?
    case
    when dir = @move_by_click.shift
      player.move(dir)
      @dir_moving = dir
    when @dir_to_move
      if @sneaking && @dir_to_move != player.direction
        player.turn(@dir_to_move)
        @sneaking = 2
      else
        player.move(@dir_to_move)
        @dir_moving = @dir_to_move
      end
      @dir_to_move = nil
    end
  end

  def on_player_unmoved(player, dir)
    if interpreter_unit.running? && @unmoved_processed.!
      @keeped_move.unshift(dir)
      @unmoved_processed = true
    else
      @keeped_move = nil
      @move_by_click.clear
    end
  end
  
  def on_start_event(unit, key, interpreter)
    if key == :main
      reset_input(true)
    end
  end

  def on_finish_event(unit, interpreter, status)
    if status.data[:key] == :main
      if @keeped_move && status.data[:wait] <= 1
        @move_by_click = @keeped_move
        @keeped_move = nil
        @pos_last_clicked = @keep_last_clicked
        @keep_last_clicked = nil
      end
      if status.data[:message]
        @move_input_count = 1
      end
    end
  end
  
  def operate_move_up
    operate_move(Itefu::Rgss3::Definition::Direction::UP)
  end

  def operate_move_down
    operate_move(Itefu::Rgss3::Definition::Direction::DOWN)
  end
  
  def operate_move_left
    operate_move(Itefu::Rgss3::Definition::Direction::LEFT)
  end

  def operate_move_right
    operate_move(Itefu::Rgss3::Definition::Direction::RIGHT)
  end
  
  def operate_move_by_click(x, y, from_x = nil, from_y = nil)
    return unless inputable?
    pu = player_unit
    mi = active_instance      # map_instance
    tm = mi.tilemap.tilemap   # tilemap
    cx = mi.normalized_cell_x((x + tm.ox) / mi.cell_size).to_i
    cy = mi.normalized_cell_y((y + tm.oy) / mi.cell_size).to_i

    if dir = pu.trigger_event_by_pos(cx, cy)
      reset_input
      # クリックでイベントを起動した
      pu.turn(dir)
    else
#ifdef :ITEFU_DEVELOP
      if pu.passable?
        reset_input
        # デバッグワープ
        pu.turn mi.dir_by_cell(pu.cell_x, pu.cell_y, cx, cy, false)
        pu.transfer_to_cell(cx, cy, true)
      else
#endif
      if cx == pu.cell_x && cy == pu.cell_y
        # キャラをクリックしたら決定ボタンと同じ動作
        operate_decide
      elsif @dclick_count > 0
        # ダブルクリックでダッシュ
        @pos_last_clicked = cx, cy
        @dclick_count = 0
        operate_dash_on
      else
        reset_input unless from_x && from_y
        if case
        when mi.passable_tile?(cx, cy, Itefu::Rgss3::Definition::Direction::NOP) || 
          pu.go_on_to_next = false
          true
        when mi.find_symbolic_event_mapobject(cx, cy, &:to_be_checked?)
          pu.go_on_to_next = true
          true
        end
          # クリックしたタイルへの移動を試みる
          path = mi.with_storategy(pu) {|p| p.find_path_by_astar(from_x || pu.cell_x, from_y || pu.cell_y, cx, cy) }
          if path.unreachable?
            unless pu.moving?
              pu.turn mi.dir_by_cell(pu.cell_x, pu.cell_y, cx, cy, false)
            end
            pu.standstill
          else
            if pu.moving?.! && @sneaking && path[0] != pu.direction
              pu.turn(path[0])
            else
              @pos_last_clicked = cx, cy
              if from_x && from_y
                @move_by_click += path
              else
                @move_by_click = path
              end
              @dclick_count = COUNT_AS_DOUBLE_CLICK
            end
          end
        end
      end
#ifdef :ITEFU_DEVELOP
      end
#endif
      pointer_unit.set_cursor_on(x, y) unless interpreter_unit.running?
    end
  end

#ifdef :ITEFU_DEVELOP
  # マップをスクロールする
  def operate_scroll_map(dir)
    return unless unit_scroll = unit(Map::Unit::Scroll.unit_id)
    return if unit_scroll.scrolling?
    if dir
      unit_scroll.start_event_scroll(dir, 1, Itefu::Rgss3::Definition::Event::Speed::MORE_FAST)
    else
      unit_scroll.reset_scroll
    end
  end

  # すり抜け状態にする
  def operate_be_ghost(ghost)
    player_unit.passable = ghost
  end

  # デバッグメニューに移動する
  def operate_go_to_debug_map
    return unless inputable?
    map_id = active_map_id
    if map_id != 255
      # save the current place to return
      pu = player_unit
      @map_id_ret_from_debug = map_id
      @cell_x_ret_from_debug = pu.cell_x
      @cell_y_ret_from_debug = pu.cell_y
      # go to the debug map
      # @magic id, cell_x, cell_y for debug map
      transfer(255, 9, 7,
        Itefu::Rgss3::Definition::Direction::NOP,
        Itefu::Rgss3::Definition::Event::FadeType::NORMAL
      )
    else
      # go back to the place where you get into the debug map
      if @map_id_ret_from_debug && @cell_x_ret_from_debug && @cell_y_ret_from_debug
        transfer(
          @map_id_ret_from_debug,
          @cell_x_ret_from_debug,
          @cell_y_ret_from_debug,
          Itefu::Rgss3::Definition::Direction::NOP,
          Itefu::Rgss3::Definition::Event::FadeType::NORMAL
        )
      end
    end
  end

  def operate_open_encounter_check
    player_unit.toggle_encounter_check
  end
#endif

end

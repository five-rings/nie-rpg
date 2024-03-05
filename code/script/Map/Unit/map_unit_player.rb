=begin  
=end
class Map::Unit::Player < Map::Unit::MapObject
  include Map::MapObject::Companion
  def default_priority; Map::Unit::Priority::PLAYER; end
  attr_accessor :go_on_to_next  # パス検索の際、目的地の隣まででも移動する

  include Game::Encounter::BellCurve

  RESUME_TARGETS = RESUME_TARGETS + [
      :@to_show_followers,
      :@step_count,         # エンカウント用歩数
      :@rate_here,          # エンカウント率計算用
      :@step_mu,            # マップの平均エンカウント歩数
#ifdef :ITEFU_DEVELOP
      :@debug_encounter_check,
#endif
  ]
  def resume_targets; RESUME_TARGETS; end

  def passable_path?(cell_x, cell_y, dir, goal_cell_x, goal_cell_y)
    nx, ny = map_instance.next_cell(cell_x, cell_y, dir)
    # 今居るタイルが進行方向へ通行可能か
    return false unless map_instance.passable_tile?(cell_x, cell_y, dir)
    # ゴールの隣までいけるなら移動する
    if self.go_on_to_next
      return true if nx == goal_cell_x && ny == goal_cell_y
    end
    # 目標のタイルが反対側から進入可能か
    return false unless map_instance.passable_tile?(nx, ny, Direction.opposite(dir))

    # マップ中にすり抜けられない表示物が存在するか
    return true if nx == goal_cell_x && ny == goal_cell_y
    return false if map_instance.find_symbolic_event_mapobject(nx, ny) {|event|
      # 通行可能なものは通り抜けられる
      next false if event.passable?
      # 通れないもののうち、接触で起動するイベントは通れるかもしれないので、それ以外の場合だけ止める
      next true unless event.current_page.trigger == Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_PLAYER
      # 透明なタイルは通れるかもしれない
      next false unless g = event.graphic
      next false if g.character_name.empty? && Itefu::Rgss3::Definition::Tile.valid_id?(g.tile_id).!
      # 絵のあるタイルも、特別なものは通れる扱いに
      next false if event.event.name.end_with?("$")
      # 絵のあるイベントは通り抜け出来ない
      true
    }
    true
  end
  
  # 隊列の表示設定を行う
  def self.setup_followers(context, to_show_followers)
    if context
      context[:@to_show_followers] = to_show_followers
    end
  end

  # 初期グラフィックを設定する
  def self.setup_player_graphic(context, chara_name, chara_index)
    if context
      graphic = RPG::Event::Page::Graphic.new
      graphic.character_name = chara_name
      graphic.character_index = chara_index
      graphic.pattern = 1
      context[:@graphic] = graphic
    end
  end
  
  # 初期位置を設定する
  def self.setup_start_position(context, cell_x, cell_y, direction)
    if context
      context[:@real_x] = context[:@real_y] = nil
      context[:@cell_x] = cell_x
      context[:@cell_y] = cell_y
      context[:@direction] = direction if Itefu::Rgss3::Definition::Direction.valid?(direction)
    end
  end

  def on_suspend
    data = super
    if self.follower
      d = data[:@follower_contexts] = []
      companion = self
      while companion = companion.follower
        # companion.apply_appearance(self)
        d << companion.on_suspend
      end
    end
    data
  end

  def gait_speed
    ipr = map_instance && interpreter
    ipr && ipr.running? && Gait::WALK || super
  end

  def initialize(*args)
    @party_members = [nil]
    clear_step_to_encounter
    @step_mu = 0
    super
  end

  def on_unit_state_changed(old)
    case unit_state
    when State::STARTED
      manage_followers
    end

    super

    case unit_state
    when State::OPENED
      show_event_icon(self.direction)
    end
  end
  
  def on_update
    manage_followers if state_started?
    super
    if sound = manager.sound_unit
      sound.move_listener(self)
    end
  end
  
  def on_moved(warped)
    # プレイヤーから接触(重なり)
    map_structure.find_event_mapobject(cell_x, cell_y) do |event|
      event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_PLAYER) ||
      event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_EVENT)
    end
    unless interpreter.running? || warped
      # イベント実行中やワープ移動の場合はエンカウントしない
      ease_state
      do_random_encounter
    end
    unless manager.quitted?
      # ランダムエンカウントで戦闘が始まっていた場合は処理しない
      show_event_icon(self.direction)
    end
    super
  end

  def on_unmoved(dir)
    # プレイヤーからの接触（隣接）
    if map_structure.walkable_tile?(cell_x, cell_y, dir)
      nx, ny = map_structure.next_cell(cell_x, cell_y, dir)
      opp_dir = Itefu::Rgss3::Definition::Direction.opposite(dir)
      map_structure.find_symbolic_event_mapobject(nx, ny) do |event|
        event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_PLAYER, opp_dir) ||
        event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::TOUCH_BY_EVENT, opp_dir)
      end
    end
    if @in_move_processing && @in_move_processing != dir
      # close_event_icon(@in_move_processing)
      show_event_icon(dir)
    end
    orientate_follower
    super
  end
  
  def finish_event_command(interpreter, status)
    # イベントの実行が終わった
    show_event_icon(self.direction)
  end

  # 隣接したイベントを探す
  # @return [Boolean] イベントに対してなんらかの処理をしたか
  def find_next_event(cx, cy, dir)
    opp_dir = Itefu::Rgss3::Definition::Direction.opposite(dir)
    begin
      cx, cy = map_structure.next_cell(cx, cy, dir)
      return true if map_structure.find_symbolic_event_mapobject(cx, cy) do |event|
        yield(event)
      end
      # 起動できるイベントはなかったが
      # カウンターなら更に奥もチェックする
    end while map_structure.counter_tile?(cx, cy)

    false
  end
  
  
  # 決定動作でイベントを起動する
  # @return [Booleab] 何かしらかのイベントを起動したか
  def trigger_event
    orientate_follower

    cx = cell_x
    cy = cell_y

    # 足下
    return true if map_structure.find_event_mapobject(cx, cy) do |event|
      event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::DECIDE)
    end

    # 隣接
    dir = direction
    opp_dir = Itefu::Rgss3::Definition::Direction.opposite(dir)
    return true if find_next_event(cx, cy, dir) do |event|
      event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::DECIDE, opp_dir)
    end

    # イベントを起動できなかった
    false
  end
  
  # 起動するイベントを座標指定する
  # @return [Boolean|Direction] イベントを起動した方向 or false
  def trigger_event_by_pos(ex, ey)
    cx = cell_x
    cy = cell_y
    
    # 足下
    return direction if (ex == cx) && (ey == cy) && map_structure.find_event_mapobject(ex, ey) do |event|
      event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::DECIDE)
    end

    # チェックする方向を決める
    dir = map_structure.dir_by_cell(cx, cy, ex, ey, true)
    return false unless Itefu::Rgss3::Definition::Direction.valid?(dir, false)
    opp_dir = Itefu::Rgss3::Definition::Direction.opposite(dir)
    
    # 隣接
    begin
      cx, cy = map_structure.next_cell(cx, cy, dir)
      if cx == ex && cy == ey
        return map_structure.find_symbolic_event_mapobject(cx, cy) {|event|
          event.trigger_event(Itefu::Rgss3::Definition::Event::Trigger::DECIDE, opp_dir)
        } && dir || false
      end
      # カウンターなら更に奥もチェックする
    end while map_structure.counter_tile?(cx, cy)

    # イベントを起動できなかった
    false   
  end
  
  # 隊列表示を切り替える
  def show_followers(to_show)
    @to_show_followers = to_show
    unless to_show
      remove_follower
      @party_members.clear
      @party_members << nil
    end
  end
  
  # 隊列を集合させる
  def gather_followers
    @follower.gather if @follower
  end
  
  # 隊列の集合待ち
  def gathering_followers?
    @follower && @follower.gathering?
  end
  
  # 指定したアクターが隊列にいればそのグラフィックを変更する
  def change_companion_graphic(actor_id, chara_name, chara_index)
    t = self
    @party_members.each do |id|
      if id == actor_id
        t.change_graphic(chara_name, chara_index)
      end
      t = t.follower
    end
  end
  
  def move(direction)
    return false if manager.quitted?
    if direction != self.direction
      @in_move_processing = self.direction
    end
    r = super
    @in_move_processing = nil
    r
  end
  
  def turn(direction)
    orientate_follower
    unless @in_move_processing || direction == self.direction
      # その場で向きを変える
      # close_event_icon(self.direction)
      show_event_icon(direction)
    end
    super
  end

  # マップ移動時にtransfer代わりに使う
  def move_map(cell_x, cell_y, dir, keep)
    self.stop_balloon_forcibly

    # エンカウント関連
    mu = @step_mu
    if mu == 0
      # 町から敵地にきたら一旦リセット
      clear_step_to_encounter
    end
    if (map_data = map_instance.map_data) && map_data.encounter_list.empty?.!
      @step_mu = map_data.encounter_step
    else
      @step_mu = 0
    end
    if @step_mu < mu
      # 平均エンカウント歩数が小さいマップに移動した場合は割合に合わせる
      # mu を越えるとエンカウント率がむしろ下がっていくため
      @step_count = @step_count * @step_mu / mu
    end

    # ユニットの移動
    if keep
      to_arrange = @follower && Itefu::Rgss3::Definition::Direction.from_pos(self.cell_x, self.cell_y, @follower.cell_x, @follower.cell_y) != Itefu::Rgss3::Definition::Direction::NOP

      # 隊列を維持して移動する
      transfer(cell_x * cell_size, cell_y * cell_size, true, false, dir || Itefu::Rgss3::Definition::Direction::NOP)

      # 前のキャラの背中側に並べる
      if to_arrange
        nx = cell_x
        ny = cell_y
        companion = self
        while f = companion.follower
          od = Itefu::Rgss3::Definition::Direction.opposite(companion.direction)
          nx, ny = Itefu::Rgss3::Definition::Direction.next(nx, ny, od)
          f.transfer(nx * cell_size, ny * cell_size, true, false)
          f.add_moving_command(Command::Move.new(companion.direction))
          companion = f
        end
      end

      turn(dir) if dir
    else
      # 隊列を集めて移動する
      transfer_to_cell(cell_x, cell_y, true)
      turn(dir) if dir
    end

    # 見た目を先頭に合わせる
    companion = self
    while companion = companion.follower
      companion.apply_appearance(self)
    end
  end

  # 隊列の一員を返す
  def find_follower(actor_id)
    companion = self.follower
    while companion
      if companion.actor_id == actor_id
        return companion
      end
      companion = companion.follower
    end
    nil
  end


private
  
  def interpreter; map_instance.event_interpreter; end

  # パーティメンバー数に応じて隊列を構成する
  def manage_followers
    return unless @to_show_followers

    # パーティ構成が変われば再編成する
    members = Map::SaveData::GameData.party.members
    return if members == @party_members
    
    # 隊列の数をパーティに合わせる
    size = @party_members.size
    hire_followers(members.size - size)
    rear_index = size - 1   # 人員変更前の最後尾
    
    # 見た目の適用
    companion = self
    rear = nil
    members.each_with_index do |id, i|
      # @note ルート移動でプレイヤーだけは変更されうるので i==0 だけは強制上書きしていない
      if i != 0
        actor = Map::SaveData::GameData.actor(members[i])
        if actor
          if id === 3
            # @magic: リルのマップグラ対応
            companion.step_anime = true
            companion.direction = Itefu::Rgss3::Definition::Direction::DOWN
            companion.direction_fixed = true
            companion.change_graphic("!Flame", 6)
          else
            companion.direction_fixed = false
            companion.step_anime = false
            companion.change_graphic(actor.chara_name, actor.chara_index)
          end
        end
        companion.actor_id = id
      end
      rear = companion if i == rear_index
      companion = companion.follower
    end

    # 位置などの指定
    if @follower
      if mi = map_instance
        @follower.replace_to_new_map(mi, mi.map_viewport)
      end
      # スクリーン上の表示位置はスクロール管理から更新されるので次フレームの更新までの間位置がおかしくならないように表示位置を合わせておく
      companion = rear
      while companion
        if f = companion.follower
          f.update_screen_xy(companion.screen_x, companion.screen_y)
        end
        companion = f
      end
      recreate_sprite
    end

    @party_members = members.clone
  end


  # パーティメンバーの分だけ隊列の人員を用意する
  def hire_followers(diff)
    return if diff == 0

    if diff > 0
      # 人員を増やす
      companion = self
      # 最後尾を探す
      while companion.follower
        companion = companion.follower
      end

      # 必要なだけ増やす
      if @follower_contexts
        contexts = @follower_contexts
        @follower_contexts = nil
      end
      diff.times {
        before = companion
        companion = companion.add_follower(self.direction)
        if contexts && (c = contexts.shift)
          companion.on_resume(c)
        else
          companion.apply_position(before)
        end
      }
    else
      # 人員を減らす
      num = number_of_followers
      companion = self
      # 減員後の最後尾を探索
      (num+diff).times {
        companion = companion.follower
      }
      # それ以降を切り離す
      companion.remove_follower
    end
  end

  # 実行可能なイベントにアイコンを表示する
  def show_event_icon(dir)
    return if interpreter.running?
    cx = self.cell_x
    cy = self.cell_y

    map_structure.event_units.each do |event|
      next if event.disabled?
      dx = (event.cell_x - cx).abs
      dy = (event.cell_y - cy).abs

      if dx + dy == 1
        # 進行不能タイル上にあるイベントを向いて隣接しているときは乗っているのと同じ扱いにする
        if dir ==  Itefu::Rgss3::Definition::Direction.from_pos(cx, cy, event.cell_x, event.cell_y) && (page = event.current_page)
          if page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::NORMAL
            # 重なれないイベント
            dx = dy = 0
          elsif event.event_tile?
            bit = Tile::Flags.directional_prohibition(Itefu::Rgss3::Definition::Direction::NOP)
            if map_structure.tileset.flags[event.tile_id] & bit == bit
              # 上に乗れないタイル
              dx = dy = 0
            end
          end
        end
      elsif dx == 0 || dy == 0
        # 対象のイベントと直線状にならんでいる
        # カウンター越しに話しかけられる可能性があるのでチェック
        ex = event.cell_x
        ey = event.cell_y
        rdir = Itefu::Rgss3::Definition::Direction.from_pos(ex, ey, cx, cy)
        while rdir != Itefu::Rgss3::Definition::Direction::NOP
          ex, ey = map_structure.next_cell(ex, ey, rdir)
          if map_structure.counter_tile?(ex, ey) && map_structure.find_symbolic_event_mapobject(ex, ey) { true }.nil?
            # どちらでもいいのでカウンターの分の距離を引く
            dx -= 1
          else
            break
          end
        end
      end
      # イベントアイコンの表示切り替え
      event.show_event_icon(dx + dy)
    end
  end

  # 歩行で解除するステートを処理する
  def ease_state
    @states_to_remove ||= []
    Map::SaveData::GameData.party.members.each do |actor_id|
      status = Map::SaveData::GameData.actor(actor_id)
      status.ease_states_due_to_walk
      status.remove_states_due_to_eased_out {|state|
        @states_to_remove << state unless state.message4.empty?
      }
    end
    @states_to_remove.uniq!

    # show messages
    a = Map::SaveData.variable(62)
    unless a === Array
      a = []
      Map::SaveData.change_variable(62, a)
    end
    @states_to_remove.each do |state|
      a << state.message4
    end
    Map::SaveData.change_switch(8, true) unless a.empty?

    @states_to_remove.clear
  end

  def clear_step_to_encounter
    @step_count = 0
    reset_encounter_calculation
  end

  # ランダムエンカウントの処理を行う
  def do_random_encounter
    return if passable?


    # エンカウント禁止チェック
    return unless Map::SaveData::GameData.system.to_encounter
    return if Map::SaveData::GameData.encounter_none?

    # 敵を選択
    index = map_instance.pick_troop_index_from_encounter_list(cell_x, cell_y)
    return unless index

#ifdef :ITEFU_DEVELOP
      if @debug_encounter_check
        n = (@debug_encounter_check[:step] += 1)
        ITEFU_DEBUG_OUTPUT_NOTICE "step #{n}"
      end
#endif

    # エンカウント率の計算
    map_data = map_instance.map_data
    mu = map_data.encounter_step
    step = @step_count += 1
    rate = calculate_encounter_rate(step, mu)

    # check if encountered
    if Map::SaveData::GameData.encounter_half?
      return unless rand * 2 < rate
    else
      return unless rand < rate
    end

    # start battle
    clear_step_to_encounter
    troop_id = map_data.encounter_list[index].troop_id
    return if troop_id < 10 # not to encounter with troops for debugging.

#ifdef :ITEFU_DEVELOP
    if @debug_encounter_check
      n = (@debug_encounter_check[:count] += 1)
      # memo list
      ITEFU_DEBUG_OUTPUT_NOTICE "encounter #{n} time Troop Id.#{troop_id}"
      Graphics.fadeout(1)
      fade = Application.fade
      fade.fade_out_with_transition(15, Itefu::Rgss3::Filename::Graphics::BATTLE_START) unless fade.faded_out?
      manager.sound.play_battle_start_se
      fade.resolve
    else
#endif
      manager.quit_by_starting_battle(troop_id, true, false, false)
#ifdef :ITEFU_DEVELOP
    end
#endif
  end

#ifdef :ITEFU_DEVELOP
public
  def toggle_encounter_check
    if @debug_encounter_check
      # @todo dump list
      @debug_encounter_check = nil
      ITEFU_DEBUG_OUTPUT_NOTICE "stopped to check encounter"
    else
      ITEFU_DEBUG_OUTPUT_NOTICE "starting to check encounter"
      @debug_encounter_check = {
        count: 0,
        step: 0,
        list: []
      }
    end
  end
#endif

end

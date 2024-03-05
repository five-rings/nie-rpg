=begin
  マップでのパスファインディング 
=end
module Map::Path
#ifdef :ITEFU_DEVELOP
  extend Itefu::Utility::Module.expect_for(Map::Structure)
#endif

  Direction = Itefu::Rgss3::Definition::Direction
  ScrollType = Itefu::Rgss3::Definition::Map::ScrollType

  # 経路用の情報を付加した配列 
  class PathArray < Array
    attr_accessor :unreachable
    def unreachable?; @unreachable; end

    def initialize(*args, &block)
      @unreachable = true
      super
    end
  end
  class PathArray
    UNREACHABLE = PathArray.new.freeze
  end

  def with_storategy(storategy)
    if block_given?
      old = @storategy
      @storategy = storategy
      ret = yield(self)
      @storategy = old
      ret
    end
  end

  # @return [Boolean] 指定した方向に通行可能かを、ゴールを考慮して、判定する
  def passable_path?(cell_x, cell_y, dir, goal_cell_x, goal_cell_y)
    return @storategy.passable_path?(cell_x, cell_y, dir, goal_cell_x, goal_cell_y) if @storategy

    nx, ny = next_cell(cell_x, cell_y, dir)
    # 今居るタイルが進行方向へ通行可能か
    return false unless passable_tile?(cell_x, cell_y, dir)
    # 目標のタイルが反対側から進入可能か
    return false unless passable_tile?(nx, ny, Direction.opposite(dir))

    # マップ中にすり抜けられない表示物が存在するか
    return true if nx == goal_cell_x && ny == goal_cell_y
    return false if find_symbolic_mapobject(nx, ny) {|event|
      event.impassable?
    }
    true
  end

  # 各種経路探索方を組み合わせて目的地までの経路を求める
  # @return [Array<Itefu::Rgss3::Definition::Direction>] 現在地からゴールまでの経路の配列
  def find_path(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth = nil)
    # LoSで探索
    path = find_path_by_los2(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth)
    return path unless path.unreachable?
    
    # だめならA*で探索
    find_path_by_astar(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth)
  end

  # LoSアルゴリズムで経路を探索する
  # @return [PathArray<Itefu::Rgss3::Definition::Direction>] 現在地からゴールまでの経路の配列
  # @param [Fixnum] start_cell_x 出発地点のx座標
  # @param [Fixnum] start_cell_y 出発地点のy座標
  # @param [Fixnum] goal_cell_x 目的地点のx座標
  # @param [Fixnum] goal_cell_y 目的地点のy座標
  # @param [Fixnum] depth 計算を打ち切る距離
  # @note ブレンハムのアルゴリズムをベースに斜め移動を禁止したもの
  def find_path_by_los(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth = nil)
    depth ||= Float::INFINITY
    path = PathArray.new

    dx = (goal_cell_x - start_cell_x)
    sx = dx > 0 ? 1 : -1
    dx = dx.abs
    if ScrollType.loop_horizontally?(map_data.scroll_type) && dx > map_data.width / 2
      dx = map_data.width - dx
      sx *= -1
    end
    dx *= 2
    dir_x = sx > 0 ? Direction::RIGHT : Direction::LEFT
    px = start_cell_x

    dy = (goal_cell_y - start_cell_y)
    sy = dy > 0 ? 1 : -1
    dy = dy.abs
    if ScrollType.loop_vertically?(map_data.scroll_type) && dy > map_data.height / 2
      dy = map_data.height - dy
      sy *= -1
    end
    dy *= 2
    dir_y = sy > 0 ? Direction::DOWN : Direction::UP
    py = start_cell_y
    
    if dx > dy
      # 横長の経路
      f = dy - dx / 2
      until (px == goal_cell_x) || (path.size >= depth)
        if f >= 0
          # 縦に移動する
          case
          when passable_cell?(px, py, dir_y)
            # 縦に移動してから横に移動する
            break unless passable_path?(px, normalized_cell_y(py + sy), dir_x, goal_cell_x, goal_cell_y)
            path.push(dir_y, dir_x)
          when passable_cell?(px, py, dir_x)
            # 横に移動してから縦に移動する
            break unless passable_path?(normalized_cell_x(px + sx), py, dir_y, goal_cell_x, goal_cell_y)
            path.push(dir_x, dir_y)
          else
            break
          end
          px = normalized_cell_x(px + sx)
          py = normalized_cell_y(py + sy)
          f = f - dx + dy
        else
          # 横に移動する
          break unless passable_path?(px, py, dir_x, goal_cell_x, goal_cell_y)
          path.push(dir_x)
          px = normalized_cell_x(px + sx)
          f += dy
        end
      end
    else
      # 縦長の経路
      f = dx - dy / 2
      until (py == goal_cell_y) || (path.size >= depth)
        if f >= 0
          # 横に移動する
          case
          when passable_cell?(px, py, dir_x)
            # 横に移動してから縦に移動する
            break unless passable_path?(normalized_cell_x(px + sx), py, dir_y, goal_cell_x, goal_cell_y)
            path.push(dir_x, dir_y)
          when passable_cell?(px, py, dir_y)
            # 縦に移動してから横に移動する
            break unless passable_path?(px, normalized_cell_y(py + sy), dir_x, goal_cell_x, goal_cell_y)
            path.push(dir_y, dir_x)
          end
          py = normalized_cell_y(py + sy)
          px = normalized_cell_x(px + sx)
          f = f - dy + dx
        else
          # 縦に移動する
          break unless passable_path?(px, py, dir_y, goal_cell_x, goal_cell_y)
          path.push(dir_y)
          py = normalized_cell_y(py + sy)
          f += dx
        end
      end
    end
    
    if (goal_cell_x == px) && (goal_cell_y == py)
      # 到達したパス
      path.unreachable = false
    end
    path
  end
  
  # LoSアルゴリズムで両方向から経路を探索する
  # @return [Array<Itefu::Rgss3::Definition::Direction>] 現在地からゴールまでの経路の配列
  # @param [Fixnum] start_cell_x 出発地点のx座標
  # @param [Fixnum] start_cell_y 出発地点のy座標
  # @param [Fixnum] goal_cell_x 目的地点のx座標
  # @param [Fixnum] goal_cell_y 目的地点のy座標
  # @param [Fixnum] depth 計算を打ち切る距離
  # @note ブレゼンハムのアルゴリズムでは斜め移動を優先するが、平行移動を優先した場合はパスが通る場合があるので、射線が通らない場合ゴール側からの逆向きの探索も試す
  def find_path_by_los2(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth = nil)
    # 普通に探索
    path1 = find_path_by_los(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth)
    return path1 unless path1.unreachable?

    # 逆側から探索
    path2 = find_path_by_los(goal_cell_x, goal_cell_y, start_cell_x, start_cell_y, depth)
    unless path2.unreachable?
      return path2.reverse!.map! {|d| Direction.opposite(d) }
    end
    
    # どちらも未到達の場合、出発点側からのパスを使うしかないので、正側を返す
    path1
  end
  
  ASTAR_NEIGHBORS = [ Direction::DOWN, Direction::RIGHT, Direction::UP, Direction::LEFT, ]

  # Path-Finding using A* Algorithm
  # @return [Array<Itefu::Rgss3::Definition::Direction>] 現在地からゴールまでの経路の配列
  # @param [Fixnum] start_cell_x 出発地点のx座標
  # @param [Fixnum] start_cell_y 出発地点のy座標
  # @param [Fixnum] goal_cell_x 目的地点のx座標
  # @param [Fixnum] goal_cell_y 目的地点のy座標
  # @param [Fixnum] depth 探索を打ち切る深さ. A*の最小のscoreがdepthを超えると処理を中断する.
  def find_path_by_astar(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth = nil)
    sorted_openlist = [[start_cell_x, start_cell_y]]
    markedlist = {
     sorted_openlist[0] => {
        cost: 0,
        score: 0,
        direction: nil,
      }
    }
    path = PathArray.new
    
    until sorted_openlist.empty?
      # 次にチェックするマスを取得
      node = sorted_openlist.shift
      current = markedlist[node]
      break if depth && current[:score] > depth

      if node[0] == goal_cell_x && node[1] == goal_cell_y
        # 目的地に到達していた
        begin
          idir = current[:direction]
          break unless idir
          path.unshift(idir)
          node = next_cell(node[0], node[1], Direction.opposite(idir))
        end while current = markedlist[node]
        path.unreachable = false
        return path
      else
        # 周辺のマスを調査する 
        ASTAR_NEIGHBORS.each do |dir|
          next_node = next_cell(node[0], node[1], dir)
          if markedlist.include?(next_node).! && passable_path?(node[0], node[1], dir, goal_cell_x, goal_cell_y)
            cost = current[:cost]
            sx = (next_node[0] - goal_cell_x).abs
            sx = map_data.width - sx if sx > map_data.width / 2
            sy = (next_node[1] - goal_cell_y).abs
            sy = map_data.height - sy if sy > map_data.height / 2
            data = {
              :cost => cost + 1,
              :score => cost + 1 + sx + sy,
              :direction => dir,
            }
            markedlist.store(next_node, data)
            index_to_insert = Itefu::Utility::Array.upper_bound(data[:score], sorted_openlist) {|a| markedlist[a][:score] }
            sorted_openlist.insert(index_to_insert, next_node)
          end
        end
      end
    end
    
    # unreachable
    path
  end

=begin
  # 対象から逃走するのに適した経路をA*を使って求める 
  # @return [CalcurateVolume, Array<Amanek::Rgss3::Direction>] 計算量, 現在地からゴールまでの経路の配列
  # @param [Fixnum] start_cell_x 出発地点のx座標
  # @param [Fixnum] start_cell_y 出発地点のy座標
  # @param [Fixnum] target_cell_x 逃げたい相手のいるのx座標
  # @param [Fixnum] target_cell_y 逃げたい相手のいるのy座標
  # @param [Fixnum] depth 何歩先までを考慮して逃走経路を計算するか
  def find_escape_path_by_astar(start_cell_x, start_cell_y, target_cell_x, target_cell_y, depth)
    neighbors = [ Amanek::Rgss3::Direction::DOWN, Amanek::Rgss3::Direction::LEFT, Amanek::Rgss3::Direction::RIGHT, Amanek::Rgss3::Direction::UP, ]
    sorted_openlist = [[start_cell_x, start_cell_y]]
    markedlist = {
      [start_cell_x, start_cell_y] => {
        :cost => 0,
        :score => 0,
        :direction => nil,
      }
    }

    until sorted_openlist.empty?
      node = sorted_openlist.pop
      current = markedlist[node]

      if current[:cost] > depth
        # found the path
        path = []
        begin
          idir = current[:direction]
          break unless idir
          path.unshift(idir)
          node = Amanek::Rgss3::Direction.next(node[0], node[1], Amanek::Rgss3::Direction.opposite(idir))
        end while current = markedlist[node]
        return path.unshift(markedlist.size)
      else
        # check the next cells
        neighbors.shuffle.each do |dir|
          next_node = Amanek::Rgss3::Direction.next(node[0], node[1], dir)
          if markedlist.include?(next_node).! && passable_path?(node[0], node[1], dir, target_cell_x, target_cell_y)
            cost = current[:cost]
            data = {
              :cost => cost + 1,
              :score => (next_node[0] - target_cell_x).abs + (next_node[1] - target_cell_y).abs,
              :direction => dir,
            }
            markedlist.store(next_node, data)
            index_to_insert = Amanek::Utility.lower_bound(data[:score], sorted_openlist) {|a| markedlist[a][:score] }
            sorted_openlist.insert(index_to_insert, next_node)
          end
        end
      end
    end
    
    # unescapable
    [markedlist.size]
  end
=end

end

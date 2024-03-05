=begin
=end
module Map::MapObject::Movable
  attr_reader   :real_x           # [Fixnum] マップ実座標でどこにいるか
  attr_reader   :real_y           # [Fixnum] マップ実座標でどこにいるか
  attr_reader   :dest_x           # [Fixnum] マップ実座標での移動先
  attr_reader   :dest_y           # [Fixnum] マップ実座標での移動先
  attr_reader   :cell_x           # [Fixnum] マップセル上でどこにいるか　(real_xから自動計算)
  attr_reader   :cell_y           # [Fixnum] マップセル上でどこにいるか　(real_yから自動計算)
  attr_reader   :direction        # [Itefu::Rgss3::Definition::Direction] 向き
  attr_reader   :jumping          # [Fixnum] ジャンプのカウンタ
  attr_accessor :move_speed       # [Itefu::Rgss3::Definition::Event::Speed] 移動速度
  attr_accessor :direction_fixed  # [Boolean] 向き固定か
  attr_accessor :passable         # [Boolean] 通過可能か
  attr_accessor :move_frequency   # [Itefu::Rgss3::Definition::Event::MoveFrequency] 移動頻度
  attr_reader   :routes           # [Array<Map::MapObject::Route>]

  def direction_fixed?; direction_fixed; end
  def passable?; passable || disabled?; end
  def impassable?; passable?.!; end
  def disabled?; false; end
  def enabled?; disabled?.!; end
  def on_moved(warped); end
  def on_unmoved(direction); end

  def player; raise Itefu::Exception::NotImplemented; end
  def cell_size; raise Itefu::Exception::NotImplemented; end
  def passable_cell?(cell_x, cell_y, direction); raise Itefu::Exception::NotImplemented; end
  def in_map_cell?(cell_x, cell_y); raise Itefu::Exception::NotImplemented; end

  def normalized_real_x(x); raise Itefu::Exception::NotImplemented; end
  def normalized_real_y(y); raise Itefu::Exception::NotImplemented; end
  def distance_cell_x(sx, gx); raise Itefu::Exception::NotImplemented; end
  def distance_cell_y(sy, gy); raise Itefu::Exception::NotImplemented; end

  Direction = Itefu::Rgss3::Definition::Direction
  Speed     = Itefu::Rgss3::Definition::Event::Speed

  def initialize(*args)
    @real_x = @dest_x = 0
    @real_y = @dest_y = 0
    @move_speed = Speed::NORMAL
    @direction = Direction::DOWN
    super
  end

  def update_movable
    return if disabled?
    if moving? || @jumping
      update_moved_position
    end
    # update_moved_positionで移動処理が終わるかもしれないのでRouteの処理条件は再度チェックする
    unless moving? || @jumping
      update_route_moving
    end
  end
 
  def draw_movable; end

  # 移動目標の位置にまだ居ない場合、近づいていく
  def update_moved_position
    dx = dest_x - real_x
    dy = dest_y - real_y
    if @jumping
      @jump_ax = dx / @jumping unless @jump_ax
      @jump_ay = dy / @jumping unless @jump_ay
      ax = @jump_ax
      ay = @jump_ay
      @jumping -= 1
    else
      rate = moving_rate
      dir = Math.atan2(dy, dx)
      ax = Math.cos(dir) * rate * cell_size
      ay = Math.sin(dir) * rate * cell_size
    end
    @real_x = (dx.abs - ax.abs < 0) ? dest_x : real_x + ax
    @real_y = (dy.abs - ay.abs < 0) ? dest_y : real_y + ay

    unless moving?
      # 移動終了時の処理
      @real_x = @dest_x = normalized_real_x(@real_x).to_i
      @real_y = @dest_y = normalized_real_y(@real_y).to_i
      update_cell_position
      @jumping = @jump_ax = @jump_ay = nil
      on_moved(false)
    end
  end

  # 現在地からセル位置を計算し更新する
  def update_cell_position
    # @note 他のオブジェクトとの重なり防止のために、移動先が決まり次第、セル上の位置は移動先に決定する
    @cell_x = normalized_cell_x((dest_x.to_f / cell_size).round)
    @cell_y = normalized_cell_y((dest_y.to_f / cell_size).round)
  end
  
  def update_route_moving
    return unless route = routes && routes[-1]
    route.update
    routes.pop if route.finished?
  end

  # --------------------------------------------------
  # 移動

  # 指定した座標に移動する
  def transfer(x, y, warp = false)
    if warp
      @real_x = @dest_x = x
      @real_y = @dest_y = y
      update_cell_position
      on_moved(true)
    else
      @dest_x = x
      @dest_y = y 
      update_cell_position
    end
  end

  # 指定したセルに移動する
  def transfer_to_cell(cell_x, cell_y, warp = false)
    transfer(cell_x * cell_size, cell_y * cell_size, warp)
  end
  
  # ジャンプ移動
  def jump(offset_x, offset_y, frame = 10)
    @jumping = frame
    transfer_to_cell(cell_x + offset_x, cell_y + offset_y, false)
  end

  # 指定した方向に移動する
  # @return [Boolean] 移動できたか
  # @param [Itefu::Rgss3::Definition::Direction] direction 移動する方向
  def move(direction)
    turn(direction)

    nx, ny = Direction.next(cell_x, cell_y, direction)
    unless in_map_cell?(nx, ny) && (passable? || passable_cell?(cell_x, cell_y, direction))
      on_unmoved(direction)
      return false
    end
  
    case direction
    when Direction::DOWN
      transfer_to_cell(cell_x, cell_y + 1)
    when Direction::LEFT
      transfer_to_cell(cell_x - 1, cell_y)
    when Direction::RIGHT
      transfer_to_cell(cell_x + 1, cell_y)
    when Direction::UP
      transfer_to_cell(cell_x, cell_y - 1)
    end
    
    true
  end
  
  def move_forward
    move(direction)
  end
  
  def move_backward
    move(Direction.opposite(direction))
  end

  def move_random
    move(Direction.random)
  end
 
  def move_toward_mapobject(movable_object)
    distance_x = distance_x_from(movable_object)
    distance_y = distance_y_from(movable_object)
    dir = Direction.from_distance_diagonal(distance_x, distance_y)
    return false unless Direction.valid?(dir, true)

    dirs = Direction.from_diagonal(dir)
    dirs.shuffle!
    moved = false
    until moved || dirs.empty?
      moved = move(dirs.pop)
    end

    moved
  end

  # プレイヤーの方以外からランダムに逃げる方を選ぶ
  def move_away_from_mapobject(movable_object)
    distance_x = distance_x_from(movable_object)
    distance_y = distance_y_from(movable_object)
    dir = Direction.from_distance_diagonal(distance_x, distance_y)
    return false unless Direction.valid?(dir, true)
    odir = Direction.opposite(dir)

    if Direction.diagonal?(dir)
      dirs = Direction.from_diagonal(odir)
    else
      dirs = Direction.complements(dir)
      2.times { dirs.push odir } # @magic: 反対方向の確立を高くする
    end

    dirs.shuffle!
    moved = false
    until moved || dirs.empty?
      moved = move(dirs.pop)
    end 

    moved
  end

  # --------------------------------------------------
  # 向き

  def turn(direction)
    return if direction_fixed?

    if Direction.valid?(direction)
      @direction = direction
    elsif Direction.valid?(direction, true)
      case self.direction
      when Direction::LEFT, Direction::RIGHT
        case direction
        when Direction::LEFT_UP, Direction::LEFT_DOWN
          @direction = Direction::LEFT
        else
          @direction = Direction::RIGHT
        end
      when Direction::UP, Direction::DOWN
        case direction
        when Direction::LEFT_UP, Direction::RIGHT_UP
          @direction = Direction::UP
        else
          @direction = Direction::DOWN
        end
      end
    end
  end
  
  def turn_toward_mapobject(movable_object)
    distance_x = distance_x_from(movable_object)
    distance_y = distance_y_from(movable_object)
    if distance_x.abs > distance_y.abs
      turn(distance_x > 0 ? Direction::RIGHT : Direction::LEFT)
    elsif distance_y != 0
      turn(distance_y > 0 ? Direction::DOWN : Direction::UP)
    else
      turn(movable_object.direction)
    end
  end
  
  def turn_away_from_mapobject(movable_object)
    distance_x = distance_x_from(movable_object)
    distance_y = distance_y_from(movable_object)
    if distance_x.abs > distance_y.abs
      turn(distance_x < 0 ? Direction::RIGHT : Direction::LEFT)
    elsif distance_y != 0
      turn(distance_y < 0 ? Direction::DOWN : Direction::UP)
    else
      turn(Direction.opposite(movable_object.direction))
    end
  end

  def turn_90_left
    turn(Direction.rotate_90_left(direction))
  end
  
  def turn_90_right
    turn(Direction.rotate_90_right(direction))
  end
  
  def turn_180
    turn(Direction.opposite(direction))
  end
  
  def turn_random
    turn(Direction.random)
  end

  # --------------------------------------------------
  # その他
  
  def distance_x_from(movable_object)
    distance_cell_x(cell_x, movable_object.cell_x)
  end

  def distance_y_from(movable_object)
    distance_cell_y(cell_y, movable_object.cell_y)
  end

  # @return [Boolean] 移動中か?
  def moving?
    (dest_x - real_x) != 0 || (dest_y - real_y) != 0
  end

  def moving_rate
    Speed.to_cell(move_speed)
  end

  def add_route_instance(route_instance)
    @routes ||= []
    @routes << route_instance
    route_instance
  end
 
end

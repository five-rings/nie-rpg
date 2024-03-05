=begin
  通行可能かなどマップの構造を表現するクラス
=end
module Map::Structure
  
  def cell_size; raise Itefu::Exception::NotImplemented; end
  def width; raise Itefu::Exception::NotImplemented; end
  def height; raise Itefu::Exception::NotImplemented; end
  def map_data; raise Itefu::Exception::NotImplemented; end
  def tileset; raise Itefu::Exception::NotImplemented; end
  def player; raise Itefu::Exception::NotImplemented; end
  def events; raise Itefu::Exception::NotImplemented; end
  def event_units; events.units; end

  Direction = Itefu::Rgss3::Definition::Direction
  Tile = Itefu::Rgss3::Definition::Tile
  ScrollType = Itefu::Rgss3::Definition::Map::ScrollType

  # ループタイプで挙動の異なる機能
  module ScrollingStrategy
    # 横方向にループする
    module LoopHorizontally
      def normalized_real_x(real_x)
        Itefu::Utility::Math.loop_size(map_data.width * cell_size, real_x)
      end
      def normalized_cell_x(cell_x)
        Itefu::Utility::Math.loop_size(map_data.width, cell_x)
      end
      def screen_x(real_x, ox)
        x = real_x - ox
        case
        when x + cell_size <= 0
          x + map_data.width * cell_size
        when x >= width 
          x - map_data.width * cell_size
        else
          x
        end
      end
      def distance_cell_x(sx, gx)
        d = gx - sx
        if d.abs * 2 > map_data.width
          if d > 0
            d - map_data.width
          else
            d + map_data.width
          end
        else
          d
        end
      end
    end
    # 縦方向にループする
    module LoopVertically
      def normalized_real_y(real_y)
        Itefu::Utility::Math.loop_size(map_data.height * cell_size, real_y)
      end
      def normalized_cell_y(cell_y)
        Itefu::Utility::Math.loop_size(map_data.height, cell_y)
      end
      def screen_y(real_y, oy)
        y = real_y - oy
        case
        when y + cell_size <= 0
          y + map_data.height * cell_size
        when y >= height 
          y - map_data.height * cell_size
        else
          y
        end
      end
      def distance_cell_y(sy, gy)
        d = gy - sy
        if d.abs * 2 > map_data.height
          if d > 0
            d - map_data.height
          else
            d + map_data.height
          end
        else
          d
        end
      end
    end
  end

  # ループタイプで挙動が異なる機能を使えるようにする
  def setup_scroll_type(scroll_type)
    if ScrollType.loop_horizontally?(scroll_type)
      self.extend ScrollingStrategy::LoopHorizontally
    end
    if ScrollType.loop_vertically?(scroll_type)
      self.extend ScrollingStrategy::LoopVertically
    end
  end

  # @return [Fixnum] マップ中座標を正規化して返す
  def normalized_real_x(real_x); real_x; end
  # @return [Fixnum] セル座標を正規化して返す
  def normalized_cell_x(cell_x); cell_x; end
  # @return [Fixnum] マップ中座標をスクリーン座標に変換する
  def screen_x(real_x, ox); real_x - ox; end
  # @return [Finum] セル間の距離
  def distance_cell_x(sx, gx); gx - sx; end

  # @return [Fixnum] マップ中座標を正規化して返す
  def normalized_real_y(real_y); real_y; end
  # @return [Fixnum] セル座標を正規化して返す
  def normalized_cell_y(cell_y); cell_y; end
  # @return [Fixnum] マップ中座標をスクリーン座標に変換する
  def screen_y(real_y, oy); real_y - oy; end
  # @return [Finum] セル間の距離
  def distance_cell_y(sy, gy); gy - sy; end

  # @return [Array<Fixnum>] 隣のセルの座標を正規化して取得する
  def next_cell(cell_x, cell_y, dir)
    n = Direction.next(cell_x, cell_y, dir)
    n[0] = normalized_cell_x(n[0])
    n[1] = normalized_cell_y(n[1])
    n
  end
  
  # @return [Direction] 始点セルから終点セルへの方向を返す
  def dir_by_cell(sx, sy, ex, ey, diagonal)
    dir = Direction.from_pos(sx, sy, ex, ey, diagonal)
    dir = Direction.flip_horizontally(dir) if (sx - ex).abs * 2 > map_data.width 
    dir = Direction.flip_vertically(dir) if (sy - ey).abs * 2 > map_data.height 
    dir
  end

  # @return [Boolean] 指定した位置から指定した方向へ移動可能か
  # @note マップ中のシンボルなど進行を妨げるもの全てを考慮する
  def passable_cell?(cell_x, cell_y, dir)
    nx, ny = next_cell(cell_x, cell_y, dir)
    # 今居るタイルが進行方向へ通行可能か
    return false unless passable_tile?(cell_x, cell_y, dir)
    # 目標のタイルが反対側から進入可能か
    return false unless passable_tile?(nx, ny, Direction.opposite(dir))
    # 目標地点にあるマップ中の表示物がすり抜け可能か
    return false if find_symbolic_mapobject(nx, ny, &:impassable?)
    true
  end

  # @return [Boolean] 歩行可能なタイルか
  # @note このセルにあるタイル自体が歩行可能なものかだけをチェックする
  def walkable_tile?(cell_x, cell_y, dir)
    nx, ny = next_cell(cell_x, cell_y, dir)
    # 今居るタイルが進行方向へ通行可能か
    return false unless passable_tile?(cell_x, cell_y, dir)
    # 目標のタイルが反対側から進入可能か
    return false unless passable_tile?(nx, ny, Direction.opposite(dir))
    true
  end
  
  # @return [Boolean] マップ内の座標か  
  def in_map_cell?(cell_x, cell_y)
    cell_x = normalized_cell_x(cell_x)
    cell_y = normalized_cell_y(cell_y)
    return cell_y >= 0 &&
           cell_y < map_data.height &&
           cell_x >= 0 &&
           cell_x < map_data.width
  end
  
  # @return [Boolean] 通過可能なタイルか
  def passable_tile?(cell_x, cell_y, dir)
    bit = Tile::Flags.directional_prohibition(dir)
    bits_dir = Tile::Flags.directional_prohibition(Itefu::Rgss3::Definition::Direction::NOP)

    # ベースとなる地形が進行可能かチェック
    # 一番下の進行可能タイルを基準として、上のタイルで進行可能な方向を増やさないようにする
    rid = rfind_tile(cell_x, cell_y) {|tile_id|
      tile_id != 0 &&
      (tileset.flags[tile_id] & Tile::Flags::OVERLAY == 0) &&
      (tileset.flags[tile_id] & bits_dir != bits_dir)
    }
    return false unless rid && tileset.flags[rid] & bit != bit

    # 地形の最上位レイヤーに進行不能タイルが置かれていないかチェック
    id = find_tile(cell_x, cell_y) {|tile_id|
      tile_id != 0 &&
      (tileset.flags[tile_id] & Tile::Flags::OVERLAY == 0)
    }
    id && tileset.flags[id] & bit != bit
  end
  
  # @return [Boolean] 店のカウンター扱いのタイルか
  def counter_tile?(cell_x, cell_y)
    rfind_tile(cell_x, cell_y) {|tile_id|
      (tileset.flags[tile_id] & Tile::Flags::COUNTER != 0)
    }.nil?.!
  end
  
  # @return [Boolean] 茂みタイルか
  def bush_tile?(cell_x, cell_y)
    rfind_tile(cell_x, cell_y) {|tile_id|
      (tileset.flags[tile_id] & Tile::Flags::BUSH != 0)
    }.nil?.!
  end
  
  # @return [Boolean] はしごタイルか
  def ladder_tile?(cell_x, cell_y)
    rfind_tile(cell_x, cell_y) {|tile_id|
      (tileset.flags[tile_id] & Tile::Flags::LADDER != 0)
    }.nil?.!
  end
  
  # @return [Fixnum] 地形タグ
  def terrain_tag(cell_x, cell_y)
    id = rfind_tile(cell_x, cell_y) {|tile_id|
      Tile::Flags.terrain_tag(tileset.flags[tile_id]) != 0
    }
    id && Tile::Flags.terrain_tag(tileset.flags[id]) || 0
  end
  
  # @return [Fixnum] タイル/イベント扱いのタイルから、条件に当てはまるtile_idを探す(上のタイルを優先)
  def find_tile(cell_x, cell_y)
    return unless in_map_cell?(cell_x, cell_y)

    case
    when r = event_units.find {|event|
        next false unless event.event_tile? &&
                    (page = event.current_page) &&
                    page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::UNDERLAY &&
                    event.cell_x == cell_x && event.cell_y == cell_y
        yield(event.tile_id)
      } 
      r && r.tile_id
    when yield(r = map_data.data[cell_x, cell_y, 2])
      r
    when yield(r = map_data.data[cell_x, cell_y, 1])
      r
    when yield(r = map_data.data[cell_x, cell_y, 0])
      r
    else
      nil
    end
  end
  
  # @return [Fixnum] タイル/イベント扱いのタイルから、条件に当てはまるtile_idを探す(下のタイルを優先)
  def rfind_tile(cell_x, cell_y)
    return unless in_map_cell?(cell_x, cell_y)
    
    case
    when yield(r = map_data.data[cell_x, cell_y, 0])
      r
    when yield(r = map_data.data[cell_x, cell_y, 1])
      r
    when yield(r = map_data.data[cell_x, cell_y, 2])
      r
    else
      r = event_units.find {|event|
        next false unless event.event_tile? &&
                    (page = event.current_page) &&
                    page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::UNDERLAY &&
                    event.cell_x == cell_x && event.cell_y == cell_y
        yield(event.tile_id)
      } 
      r && r.tile_id
    end
  end

  # @return [Fixnum] 指定したセルのタイルID
  def tile_id(cell_x, cell_y, index)
    ITEFU_DEBUG_ASSERT(index >= 0 && index <= 2)
    in_map_cell?(cell_x, cell_y) ? map_data.data[cell_x, cell_y, index] : 0
  end

  # @return [Fixnum] 指定したセルのリージョンID
  def region_id(cell_x, cell_y)
    in_map_cell?(cell_x, cell_y) ? map_data.data[cell_x, cell_y, 3] >> 8 : 0
  end

  # @return [Array<Array<Fixnum>>] 指定したリージョンのタイル座標の配列
  def region_tiles(region_id)
    if block_given?
      map_data.height.times do |cell_y|
        map_data.width.times do |cell_x|
          yield(cell_x, cell_y) if region_id == map_data.data[cell_x, cell_y, 3] >> 8
        end
      end
    else
      r = []
      map_data.height.times do |cell_y|
        map_data.width.times do |cell_x|
          r << [cell_x, cell_y] if region_id == map_data.data[cell_x, cell_y, 3] >> 8
        end
      end
      r
    end
  end

  # return [Boolean] 指定したIDのリージョンが設定されたタイルが存在するか
  def regioned_tile?(region_id)
    map_data.height.times do |cell_y|
      map_data.width.times do |cell_x|
        return true if region_id == map_data.data[cell_x, cell_y, 3] >> 8
      end
    end
    false
  end
  
  # @return [Map::Unit::Event] 条件に合うタイル状のイベントを探す
  def find_tile_mapobject(cell_x, cell_y)
    event_units.find {|event|
      next false unless Tile.valid_id?(event.tile_id) &&
                  event.enabled? &&
                  event.cell_x == cell_x && event.cell_y == cell_y
      yield(event)
    } 
  end

  # @return [Map::Unit::MapObject] 条件にあうMapObjectを探す(Playerを含む)
  def find_symbolic_mapobject(cell_x, cell_y)
    r = nil
    return r if r = event_units.find do |event|
      next false unless event.enabled? &&
                  (page = event.current_page) &&
                  page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::NORMAL &&
                  event.cell_x == cell_x && event.cell_y == cell_y
      yield(event)
    end 
    return r if player_here?(cell_x, cell_y) && yield(r = player)
    nil
  end

  # @return [Map::Unit::Event>] プレイヤーと接触しうるイベントから条件に合うものを返す
  def find_symbolic_event_mapobject(cell_x, cell_y)
    event_units.find do |event|
      next false unless event.enabled? &&
                  (page = event.current_page) &&
                  page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::NORMAL &&
                  event.cell_x == cell_x && event.cell_y == cell_y
      yield(event)
    end 
  end
  
  # @return [Map::Unit::Event] 条件に合うイベントを返す
  def find_event_mapobject(cell_x, cell_y)
    event_units.find do |event|
      next false unless event.cell_x == cell_x && event.cell_y == cell_y
      yield(event)
    end 
  end
  
  # @return [Array<MapObject::Movable>] 指定したセルに配置されたプレイヤーと接触しうるMapObjectの配列
  def symbolic_mapobjects(cell_x, cell_y, output = nil)
    objects = symbolic_event_mapobjects(cell_x, cell_y, output)
    objects << player if player_here?(cell_x, cell_y)
    objects
  end
  
  # @return [Array<MapObject::Movable>] 指定したセルに配置されたプレイヤーと接触し得るイベントの配列
  def symbolic_event_mapobjects(cell_x, cell_y, output = nil)
    event_units.each_with_object(output || []) {|event, m|
      next unless event.enabled? &&
                  (page = event.current_page) &&
                  page.priority_type == Itefu::Rgss3::Definition::Event::PriorityType::NORMAL &&
                  event.cell_x == cell_x && event.cell_y == cell_y
      m << event
    }
  end
  
  # @return [Array<MapObject::Movable>] 指定したセルに配置されたイベントの配列
  def event_mapobjects(cell_x, cell_y, output = nil)
    event_units.each_with_object(output || []) {|event, m|
      next unless event.cell_x == cell_x && event.cell_y == cell_y
      m << event
    }
  end
  
  # @return [Boolean] 指定座標にプレイヤーがいるか
  def player_here?(cell_x, cell_y)
    player.cell_x == cell_x && player.cell_y == cell_y
  end

  # @return [Fixnum] 指定したセルが所属するマップを分割した空間のindexを返す
  def map_space_index(cell_x, cell_y)
    row = map_space_row(cell_x)
    col = map_space_col(cell_y)
    ws = width * 3 / (cell_size * 4)
    wn = (map_data.width.to_f / ws).ceil
    row + col * wn
  end
  
  # @return [Fixnum] 指定したセルがマップを分割した空間の何列目にあるかを返す
  def map_space_row(cell_x)
    cell_x * cell_size * 4 / (width * 3)
  end
  
  # @return [Fixnum] 指定したセルがマップを分割した空間の何行目にあるかを返す
  def map_space_col(cell_y)
    cell_y * cell_size * 4 / (height * 3)
  end

  # @return [Array<Fixnum>] マップを分割した空間のうち更新対象になるもののindexを集めて返す
  # @param [Fixnum] real_x 画面の左端がマップ中のどこにあるか
  # @param [Fixnum] real_y 画面の上端がマップ中のどこにあるか
  # @param [Array] output 生成住みのArrayオブジェクトを指定すると結果をこれに追加するようになる
  def map_space_indices(real_x, real_y, output = nil)
    output ||= []

    qw = width  / 4
    qh = height / 4
    cs4 = cell_size * 4
    ws = width  * 3 / cs4
    hs = height * 3 / cs4
    wn = (map_data.width.to_f / ws).ceil
    hn = (map_data.height.to_f / hs).ceil
    # 更新範囲の上下左右端に相当するセル座標が属する分割空間のindex
    sxi = map_space_row normalized_cell_x(((real_x + qw * -1).to_f / cell_size).round)
    exi = map_space_row normalized_cell_x(((real_x + qw *  5).to_f / cell_size).round)
    syi = map_space_col normalized_cell_y(((real_y + qh * -1).to_f / cell_size).round)
    eyi = map_space_col normalized_cell_y(((real_y + qh *  5).to_f / cell_size).round)
    # 非ループ時ははみ出す場合があるので範囲内に納める
    sxi = Itefu::Utility::Math.clamp(0, wn-1, sxi)
    exi = Itefu::Utility::Math.clamp(0, wn-1, exi)
    syi = Itefu::Utility::Math.clamp(0, hn-1, syi)
    eyi = Itefu::Utility::Math.clamp(0, hn-1, eyi)

    # 左端から右端の更新対象を列挙
    xarray = []
    xi = sxi
    begin
      xi = Itefu::Utility::Math.loop_size(wn, xi + 1)
      xarray << xi
    end until (xi == exi)
    xarray << sxi if sxi != exi

    # 上端から下端の更新対象を列挙
    yarray = []
    yi = syi
    begin
      yi = Itefu::Utility::Math.loop_size(hn, yi + 1)
      yarray << yi
    end until(yi == eyi)
    yarray << syi if syi != eyi

    # row,colをindexに変換する
    yarray.each do |iy|
      co = iy * wn
      xarray.each do |ix|
        output << (ix + co)
      end
    end

    output
  end

end

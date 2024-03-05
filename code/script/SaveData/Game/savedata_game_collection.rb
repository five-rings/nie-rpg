=begin
  コレクション関連の進行データ
=end
class SaveData::Game::Collection < SaveData::Game::Base
  attr_reader :home_points
  attr_reader :home_place
  attr_reader :home_point
  attr_reader :episodes
  attr_reader :event_checked

  def initialize
    @home_place = nil   # 女神帰還の帰り先
    @home_points = {}   # 訪れた妖精の集い
    @home_point = nil   # 妖精帰還の帰り先
    @episodes = { unknown_place: true }
    @event_checked = {}
  end

  # 拠点を登録する
  def register_home_place(map_id, cell_x, cell_y, dir, name)
    @home_place = {
      map_id: map_id,
      x: cell_x,
      y: cell_y,
      d: dir,
      name: name,
    }
  end
  
  # 拠点が登録されているか
  def home_place_registered?; @home_place.nil?.!; end

  # 最後にアクセスした妖精の集いを記録する
  # @note add_home_pointの返り値を設定する
  def register_home_point(pos)
    @home_point = pos
  end

  # 妖精の集いの帰り先が登録されているか
  def home_point_registered?; @home_point.nil?.!; end

  # 帰還ポイントを新しく登録する
  def add_home_point(map_id, cell_x, cell_y, dir, name)
    ps = @home_points[map_id] ||= []
    p = ps.find {|pos|
      pos[:x] == cell_x && pos[:y] == cell_y
    }
    if p
      p[:d] = dir
      p[:name] = name
      p
    else
      ps.push map_id: map_id, x: cell_x, y: cell_y, d: dir, name: name
      ps.last
    end
  end

  # 指定した場所に一番ちかい帰還ポイントを取得する
  def home_point_nearest(map_id, cell_x, cell_y)
    return unless ps = @home_points[map_id]
    ps.min_by {|pos|
      # マンハッタン距離
      (pos[:x] - cell_x).abs + (pos[:y] - cell_y).abs
    }
  end

  # 指定したマップの帰還ポイントがあるか
  def home_points?(map_id)
    ps = @home_points[map_id]
    ps && ps.empty?.!
  end

  # エピソード情報を公開する
  def open_episode(key)
    # 未チェック状態で解放
    @episodes[key] ||= false
  end

  def episode_open?(key)
#ifdef :ITEFU_DEVELOP
    @all_episodes_opened ||
#endif
    @episodes.has_key?(key)
  end

  # 一つでもエピソード情報が解放されているか
  def some_episode_open?
#ifdef :ITEFU_DEVELOP
    @all_episodes_opened ||
#endif
    @episodes.size > 1 # デフォルト解放分は除く
  end

  def episode_checked?(key)
    @episodes[key]
  end

  def check_episode(key)
    # チェック状態にする
    @episodes[key] = true
  end

#ifdef :ITEFU_DEVELOP
  def open_all_episodes
    @all_episodes_opened = true
  end
#endif


  def check_event(map_id, event_id, page_index)
    hmap = @event_checked[map_id] ||= {}
    hev = hmap[event_id] ||= {}
    hev[page_index] = true
  end

  def check_event_flag(map_id, event_id, page_index, bit)
    hmap = @event_checked[map_id] ||= {}
    hev = hmap[event_id] ||= {}
    hev[page_index] ||= 0
    hev[page_index] |= bit
  end

  def event_flag_checked?(map_id, event_id, page_index, bit)
#ifdef :ITEFU_DEVELOP
    @event_checked ||= {}
#endif
    return false unless hmap = @event_checked[map_id]
    return false unless hev = hmap[event_id]
    (hev[page_index] & bit) == bit
  end

  def event_checked?(map_id, event_id, page_index)
#ifdef :ITEFU_DEVELOP
    @event_checked ||= {}
#endif
    return false unless hmap = @event_checked[map_id]
    return false unless hev = hmap[event_id]
    case hev[page_index]
    when TrueClass
      true
    else
      false
    end
  end

  # 女神・妖精帰還先のマップ名
  def name_of_home_place(home = @home_place)
    return unless hp = home
    return unless id = hp[:map_id]
    msg = Application.language.load_message(:map_name)
    name = msg.text(("Map%03d" % id).intern) || hp[:name]
    Application.language.release_message(:map_name)
    name
  end

end


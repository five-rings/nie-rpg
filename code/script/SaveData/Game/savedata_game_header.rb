=begin
  ゲーム進行データのロード画面表示用ヘッダ
=end
class SaveData::Game::Header < SaveData::Game::Base
  attr_accessor :timestamp        # [Time] 保存した時刻
  attr_accessor :playing_time     # [Fixnum] 総プレイ時間(秒)
  attr_accessor :actor_level      # [Fixnum] レベル
  attr_accessor :map_id           # [Fixnum] セーブ時にいたマップのID
  attr_accessor :map_name         # [String] セーブ時にいたマップ名
  # attr_accessor :chapter_name     # [String: セーブ時の章題
  attr_accessor :summaries        # [Array] アクターの情報
  
  Summary = Struct.new(:level, :hp, :mp, :exp, :face_name, :face_index)
  
  def initialize
    self.playing_time = 0
    on_load
  end
  
  def on_load
    @time_loaded = Time.now
  end
  
  def on_save(data)
    apply_time(Time.now)
    apply_actors(data[:party], data[:actors])
    apply_map_name(data[:map])
  end
  
private

  def apply_time(time_now)
    self.timestamp = time_now
    self.playing_time += (time_now - @time_loaded).to_i
    @time_loaded = time_now
  end

  def apply_actors(party, actors)
    actor_id_highest = party.members.max_by {|actor_id|
      actors[actor_id] && actors[actor_id].level || 0
    }
    self.actor_level = actors[actor_id_highest].level || 0

    self.summaries = party.members.map {|actor_id|
      if actor = actors[actor_id]
        Summary.new(
          actor.level,
          actor.mhp, actor.mmp,
          actor.total_exp,
          actor.face_name,
          actor.face_index
        )
      end
    }
    self.summaries.compact!
  end

  def apply_map_name(map)
    self.map_id = map.map_id
    self.map_name = map.map_name
  end

end

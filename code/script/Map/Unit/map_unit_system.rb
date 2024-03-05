=begin
  分割するほどではないもの
=end
class Map::Unit::System < Map::Unit::Base
  def default_priority; Map::Unit::Priority::SYSTEM; end

  def on_suspend
    sound = manager.sound
    {
      mpr_counter: @mpr_counter,
      original_volume: @original_volume,
      sound: [sound.actual_bgm, sound.actual_bgs],
      lock_bgm: @lock_bgm,
      events: @events,
    }
  end
  
  def on_resume(context)
    @mpr_counter = context[:mpr_counter] || 0
    @original_volume = context[:original_volume]
    @cached_sound = context[:sound]
    @lock_bgm = context[:lock_bgm]
    @events = context[:events].concat(@events)
  end

  def on_initialize
    @mpr_counter = 0
    @events = []
  end

  def on_finalize
  end
  
  def on_update
    return unless state_started?

    if (@mpr_counter += 1) > Graphics.frame_rate
      @mpr_counter = 0
      recover_mp
    end

    process_event
  end
  
  # MPを回復する
  def recover_mp
=begin
    savedata = @savedata.current_data
    savedata.party.members.each do |id|
      actor = savedata.actors[id]
      actor.recover_mp_automatically
    end
=end
  end

  # マップのBGMを固定する
  def lock_bgm(value)
    @lock_bgm = value
  end
  
  # マップのBGM/BGSを再生する
  def play_map_sound(map_data)
    return unless sound = manager.sound

    if @cached_sound
      # 保存した状態から再開したので元に戻す
      @cached_sound.each do |s|
        if sound.playing?(s)
          # 再生中のBGMが同じ場合
          case s
          when RPG::BGM
            bgm = sound.actual_bgm
            if bgm.volume != s.volume
              sound.fade_bgm_volume(s.volume)
            end
          when RPG::BGS
            bgs = sound.actual_bgs
            if bgs.volume != s.volume
              sound.fade_bgs_volume(s.volume)
            end
          end
        else
          sound.play(s)
        end
      end
      @cached_sound = nil 
    else
      # 通常のサウンド変更
      # BGM
      unless @lock_bgm
        if map_data.autoplay_bgm
          # マップで指定されたBGMの再生
          if sound.playing_bgm?(map_data.bgm)
            sound.fade_bgm_volume(map_data.bgm.volume)
          else
            sound.play(map_data.bgm)
          end
          @original_volume = map_data.bgm.volume
        else
          # ボリュームだけの変更
          @original_volume ||= sound.actual_bgm.volume
          volume_rate = Itefu::Utility::String.note_command_f(:volume=, map_data.note) || 1.0
          volume = (@original_volume * volume_rate).to_i
          sound.fade_bgm_volume(volume)
        end
      end
      # BGS
      if map_data.autoplay_bgs
        # マップで指定されたBGSの再生
        if sound.playing_bgs?(map_data.bgs)
          sound.fade_bgs_volume(map_data.bgs.volume)
        else
          sound.play(map_data.bgs)
        end
      end
    end
  end

  # 実行したいイベントを外部から登録する
  def reserve_event(event)
    @events << event
  end

  # 外部から登録されたイベントを実行する
  def process_event
    return unless interpreter = manager.interpreter_unit
    return unless event = @events[0]

    if interpreter.start_main_event(manager.active_map_id, nil, event.id, event.list)
      @events.shift
    end
  end

end


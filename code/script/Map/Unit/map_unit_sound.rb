=begin
  マップ中の音源を管理する
  @note BGMなどは含まれない。マップ中にイベントとして配置されるものを扱う。
=end
class Map::Unit::Sound < Map::Unit::Base
  def default_priority; Map::Unit::Priority::SOUND; end
  def sound; manager.sound; end

  def on_initialize
  end
  
  def on_finalize
  end

  # @return [Itefu::Sound::Environment] 元のインスタンスを返す
  def switch_environment(environment)
    env = sound.environment
    sound.environment = environment
    env
  end
  
  # イベントを音源として登録する
  # @note 音源でないイベントの場合、登録を解除する
  def attach_source(event)
    page = event.current_page
    return detach_source(event) unless page
    
    param = page.list.find {|command|
      # 冒頭にある注釈だけを確認する
      break unless (command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT ||
                    command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT_SEQUEL)
      if /^\*(\w+)\s*\=\s*(.+)$/ === command.parameters[0]
        # *sound=a,c,b..を探す
        if $1 == "sound"
          break $2
        end
      end
    }
    return detach_source(event) unless param
    params = param.split(",")

    name = params.shift
    params.map!(&:to_f)

    play_bgs(event, name, *params)
  end
  
  def play_bgs(event, name, volume, pitch, *args)
    source = sound.environment.play_bgs(
      event.event_id,
      event.real_x, event.real_y,
      name, volume, pitch
    )
    source.attenuation = Sound::Map::Attenuator::SimpleEllipse.new(*args)
  end
  private :play_bgs
  
  # 音源として登録されたイベントを取り除く
  def detach_source(event)
    if env = sound.environment
      env.stop_bgs(event.event_id, 500)
    end
  end

  # 音源の位置を更新する
  def move_source(event)
    sound.environment.move_bgs(
      event.event_id,
      event.real_x,
      event.real_y
    )
  end
  
  # リスナの位置を更新する
  def move_listener(mapobject)
    sound.environment.move_listener(
      mapobject.real_x,
      mapobject.real_y
    )
  end

end

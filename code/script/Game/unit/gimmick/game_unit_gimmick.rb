=begin
   画面効果、天候、特殊効果など 
=end
module Game::Unit::Gimmick

  ToneContext = Struct.new(:duration, :tone_dest)
  ShakeContext = Struct.new(:duration, :power, :speed, :sign, :sign_base, :offset)
  FlashContext = Struct.new(:duration)

  def gimmick_klass; Game::Unit::Gimmick; end

  def gimmick(id); @gimmicks[id]; end

  def on_initialize(viewport)
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, viewport)
    @viewport.tone = Tone.new
    @viewports = {}
    @tone_context = ToneContext.new(0, nil)
    @shake_context = ShakeContext.new(0, 0, 0, 1, 1, 0)
    @flash_context = FlashContext.new(0)
    @gimmicks = {}
  end

  def add_viewport(target, viewport)
    @viewports[target] = Itefu::Rgss3::Resource.swap(@viewports[target], viewport)
  end

  def on_finalize
    @gimmicks.each_value(&:finalize)
    @gimmicks.clear
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, nil)
    @viewports.each_value {|vp| Itefu::Rgss3::Resource.swap(vp, nil) }
    @viewports.clear
  end

  def on_update
    update_tone
    update_shake
    update_flash
    @gimmicks.each_value(&:update)
  end

  # 色調を変更する
  def change_tone(tone, duration)
    if duration > 0 && tone
      @viewport.tone = @tone_context.tone_dest if changing_tone?
      @tone_context.tone_dest = Tone.new.set(tone)
      @tone_context.duration = duration
    else
      @tone_context.duration = 0
      @viewport.tone.set(tone)
    end
  end

  # 色調変更中か
  def changing_tone?
    @tone_context.duration > 0
  end

  # 画面を揺らす
  def shake(power, speed, duration)
    @shake_context.duration = duration
    @shake_context.power = power
    @shake_context.speed = speed
    @shake_context.sign_base *= -1 # 揺れを左右交互にする
    @shake_context.sign = @shake_context.sign_base
    @shake_context.offset = @viewport.ox
  end

  # 画面を揺らしているか
  def shaking?
    @shake_context.duration > 0
  end

  # 画面を指定色で上書きする
  def flash(color, duration)
    @flash_context.duration = duration
    @viewport.color.set(color)
  end

  # 画面の色を上書きしているか
  def flashing?
    @flash_context.duration > 0
  end

  # 天候を変更する
  def change_weather(weather_type, power, duration, *args)
    klass = gimmick_klass_from_type(weather_type)
    ITEFU_DEBUG_ASSERT(klass, "unknown weather_type #{weather_type} specified")
    if klass === @gimmicks[:weather]
      @gimmicks[:weather].change_power(power, duration, *args)
    else
      add_gimmick(:weather, klass, power, duration, *args)
    end
  end

  # 現在の天候
  def current_weather_type
    if weather = @gimmicks[:weather]
      weather.type
    else
      Itefu::Rgss3::Definition::Event::WeatherType::NONE
    end
  end

  # gimmickを追加
  def add_gimmick(id, klass, *args)
    @gimmicks[id].finalize if @gimmicks.has_key?(id)
    if klass 
      vp = @viewports[id] || @viewport
      gimmick = klass.new(self, vp, *args)
      @gimmicks[id] = gimmick
    else
      @gimmicks.delete(id)
    end
  end

  # 追加効果を設定する
  def change_additional_gimmick(gimmick_type, *args)
    klass = gimmick_klass_from_type(gimmick_type)
    if klass && klass.ancestors.include?(Weather)
      add_gimmick(:weather, klass, *args)
    else
      add_gimmick(:additional, klass, *args)
    end
  end

private

  # gimmick_typeからクラス名に変換する
  def gimmick_klass_from_type(gimmick)
    name = gimmick && Itefu::Utility::String.upper_camel_case(gimmick.to_s)
    if name && gimmick_klass.const_defined?(name)
      gimmick_klass.const_get(name)
    else
      ITEFU_DEBUG_OUTPUT_WARNING "gimmick #{name} is not defined at #{gimmick_klass}"
    end
  end

  def update_tone
    return unless changing_tone?
    d = @tone_context.duration
    @tone_context.duration -= 1

    tone = @viewport.tone
    tone_dest = @tone_context.tone_dest

    tone.red   = (tone.red   * (d-1) + tone_dest.red)   / d
    tone.green = (tone.green * (d-1) + tone_dest.green) / d
    tone.blue  = (tone.blue  * (d-1) + tone_dest.blue)  / d
    tone.gray  = (tone.gray  * (d-1) + tone_dest.gray)  / d
  end

  def update_shake
    return unless shaking?
    delta = (@shake_context.power * @shake_context.speed * @shake_context.sign) / 10.0
    if @shake_context.duration <= 1
      @shake_context.offset = 0
    else
      @shake_context.offset += delta
      @shake_context.sign *= -1 if @shake_context.offset.abs > @shake_context.power * 2
    end
    @shake_context.duration -= 1
    @viewport.ox = @shake_context.offset
  end

  def update_flash
    return unless flashing?
    d = @flash_context.duration
    @viewport.color.alpha = @viewport.color.alpha * (d - 1) / d
    @flash_context.duration -= 1
  end

end

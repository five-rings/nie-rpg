=begin
  天候の共通クラス
=end
module Game::Unit::Gimmick::Weather
  def type; raise Itefu::Exception::NotImplemented; end
  def create_particle_bitmap; raise Itefu::Exception::NotImplemented; end
  def update_particles; raise Itefu::Exception::NotImplemented; end

  def suspend; [@target_power, @duration, @power]; end

  module Color
    extend Color
    extend Itefu::Color::Declaration
    declare_color(:Particle1, 0xff, 0xff, 0xff, 192)
    declare_color(:Particle2, 0xff, 0xff, 0xff, 96)
  end

  def dimness
    (@power * 6).to_i
  end
  
  
  def initialize(parent_unit, viewport, target_power, duration, power = 0)
    @sprites = []
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, viewport)
    @target_power = target_power.to_f
    @duration = duration
    @particle_bitmap = create_particle_bitmap
    change_current_power(duration > 0 ? power : target_power)
  end
  
  def finalize
    @sprites.each(&:dispose)
    @sprites.clear    
    @particle_bitmap = Itefu::Rgss3::Resource.swap(@particle_bitmap, nil)
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, nil)
  end
  
  def update
    update_power
    update_dimness
    update_particles
  end

  def change_power(target_power, duration)
    @target_power = target_power
    @duration = duration
    change_current_power(target_power) unless duration > 0
  end
  
private
 
  def number_of_particles
    @power * 10
  end
  
  def width
    # @viewport && @viewport.width ||
    Graphics.width
  end
  
  def height
    # @viewport && @viewport.height ||
    Graphics.height
  end

  def update_power
    if @duration > 0
      d = @duration
      change_current_power((@power * (d - 1) + @target_power) / d)
      @duration -= 1
    end 
  end

  def update_dimness
    return unless @viewport
    v = -dimness
    @viewport.tone.set(v, v, v)
  end

  def change_current_power(power)
    @power = power

    # spriteの数を変更
    diff = (@sprites.size - number_of_particles).to_i
    if diff < 0
      diff.abs.times {
        s = Itefu::Rgss3::Sprite.new(@viewport)
        s.bitmap = @particle_bitmap
        reset_particle(s)
        @sprites << s
      }
    elsif diff > 0
      s = @sprites.pop(diff)
      s.each(&:dispose)
    end
  end
  
  def reset_particle(sprite)
    sprite.x = rand(width  + 100) - 100
    sprite.y = rand(height + 200) - 200
    sprite.opacity = 160 + rand(96)
  end

end

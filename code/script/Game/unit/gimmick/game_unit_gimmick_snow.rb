=begin
=end
class Game::Unit::Gimmick::Snow
  include Game::Unit::Gimmick::Weather
  def type; Itefu::Rgss3::Definition::Event::WeatherType::SNOW; end

  def suspend; [@target_power, @duration, @power, @speed]; end

  def initialize(parent_unit, viewport, target_power, duration, power = 0, speed = nil)
    @speed = speed
    super(parent_unit, viewport, target_power, duration, power)
  end

  def change_power(target_power, duration, speed = nil)
    @speed = speed if speed
    super(target_power, duration)
  end

private

  def update_particles
    @sprites.each do |sprite|
      sprite.x -= 1
      sprite.y += @speed || 3
      sprite.opacity -= 12
      reset_particle(sprite) if sprite.opacity < 64
    end
  end

  def create_particle_bitmap
    bitmap = Itefu::Rgss3::Bitmap.new(6, 6)
    bitmap.fill_rect(0, 1, 6, 4, Color.Particle2)
    bitmap.fill_rect(1, 0, 4, 6, Color.Particle2)
    bitmap.fill_rect(1, 2, 4, 2, Color.Particle1)
    bitmap.fill_rect(2, 1, 2, 4, Color.Particle1)
    bitmap
  end

end

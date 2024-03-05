=begin
=end
class Game::Unit::Gimmick::Rain
  include Game::Unit::Gimmick::Weather
  def type; Itefu::Rgss3::Definition::Event::WeatherType::RAIN; end


private

  def update_particles
    @sprites.each do |sprite|
      sprite.x -= 1
      sprite.y += 6
      sprite.opacity -= 12
      reset_particle(sprite) if sprite.opacity < 64
    end
  end
  
  def create_particle_bitmap
    bitmap = Itefu::Rgss3::Bitmap.new(7, 42)
    7.times {|i| bitmap.fill_rect(6-i, i*6, 1, 6, Color.Particle1) }
    bitmap
  end
  
end

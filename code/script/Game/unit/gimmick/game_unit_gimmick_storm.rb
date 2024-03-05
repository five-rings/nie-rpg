=begin
=end
class Game::Unit::Gimmick::Storm
  include Game::Unit::Gimmick::Weather
  def type; Itefu::Rgss3::Definition::Event::WeatherType::STORM; end


private

  def update_particles
    @sprites.each do |sprite|
      sprite.x -= 3
      sprite.y += 6
      sprite.opacity -= 12
      reset_particle(sprite) if sprite.opacity < 64
    end
  end

  def create_particle_bitmap
    bitmap = Itefu::Rgss3::Bitmap.new(34, 34)
    32.times do |i|
      bitmap.fill_rect(33-i, i*2, 1, 2, Color.Particle2)
      bitmap.fill_rect(32-i, i*2, 1, 2, Color.Particle1)
      bitmap.fill_rect(31-i, i*2, 1, 2, Color.Particle2)
    end
    bitmap
  end
  
end

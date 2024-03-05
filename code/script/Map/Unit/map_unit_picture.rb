=begin
=end
class Map::Unit::Picture < Game::Unit::Picture
  def default_priority; Map::Unit::Priority::PICTURE; end
  include Map::Unit::Base::Implement

  def on_suspend
    @data_container.map {|key, value|
      current_tone = value.sprite.tone
      if current_tone
        tone = Tone.new
        tone.set(current_tone)
      else
        tone = nil
      end
      {
        :index => key,
        :name => value.name,
        :origin => value.origin,
        :x => value.sprite.x,
        :y => value.sprite.y,
        :zoom_x => value.sprite.zoom_x,
        :zoom_y => value.sprite.zoom_y,
        :opacity => value.sprite.opacity,
        :blend_type => value.sprite.blend_type,
        :tone => tone,
        :angle => value.sprite.angle,
        :angle_velocity => value.angle_velocity,
      }
    }
  end
  
  def on_resume(context)
    context.each do |c|
      index = c[:index]
      show(index, c[:name], c[:origin], c[:x], c[:y], c[:zoom_x], c[:zoom_y], c[:opacity], c[:blend_type])
      data = @data_container[index]
      data.sprite.angle = c[:angle]
      tone = c[:tone]
      data.sprite.tone = tone if tone
      rotate(index, c[:angle_velocity])
    end
  end

end

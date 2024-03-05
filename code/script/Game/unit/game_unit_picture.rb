=begin
=end
class Game::Unit::Picture < Itefu::Unit::Base
  include Itefu::Resource::Loader
  include Itefu::Animation::Player

  class Data
    attr_accessor :sprite
    attr_accessor :res_id
    attr_accessor :name
    attr_accessor :origin
    attr_accessor :angle_velocity
    
    def initialize
      @sprite = nil
      @res_id = nil
      @name = ""
      @origin = Itefu::Rgss3::Definition::Event::Picture::Origin::LEFT_TOP
      @angle_velocity = 0
    end
  end

  def on_initialize(viewport)
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, viewport)
    @data_container = {}
  end

  def on_finalize
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, nil)
    finalize_animations
    @data_container.each do |index, data|
      data.sprite.dispose
    end
    @data_container.clear
    release_all_resources
  end

  def on_update
    update_animations
    update_rotation
  end


  # 表示されているか
  def shown?(index)
    @data_container.has_key?(index)
  end

  # 指定したピクチャを消す
  def erase(index)
    if shown?(index)
      anime = animation([index, :move])
      anime.finish if anime
      anime = animation([index, :tone])
      anime.finish if anime

      data = @data_container.delete(index)
      data.sprite.dispose
      release_resource(data.res_id)
      data
    end
  end
  
  # ピクチャを表示する
  def show(index, name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
    data = Data.new
    data.name = name
    data.origin = origin
    data.res_id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::PICTURES_s % name)
    data.sprite = Sprite.new(@viewport)
    data.sprite.bitmap = resource_data(data.res_id)
    case origin
    when Itefu::Rgss3::Definition::Event::Picture::Origin::LEFT_TOP
      data.sprite.ox = 0
      data.sprite.oy = 0
    when Itefu::Rgss3::Definition::Event::Picture::Origin::CENTER
      data.sprite.ox = data.sprite.bitmap.width  / 2
      data.sprite.oy = data.sprite.bitmap.height / 2
    else
      raise Itefu::Exception::Unreachable
    end
    data.sprite.x = x
    data.sprite.y = y
    data.sprite.zoom_x = zoom_x
    data.sprite.zoom_y = zoom_y
    data.sprite.opacity = opacity
    data.sprite.blend_type = blend_type

    erase(index)
    @data_container[index] = data
  end
  
  # 位置移動
  def move(index, origin, x, y, zoom_x, zoom_y, opacity, blend_type, duration)
    return unless shown?(index)

    data = @data_container[index]
    data.origin = origin
    case origin
    when Itefu::Rgss3::Definition::Event::Picture::Origin::LEFT_TOP
      data.sprite.ox = 0
      data.sprite.oy = 0
    when Itefu::Rgss3::Definition::Event::Picture::Origin::CENTER
      data.sprite.ox = data.sprite.bitmap.width / 2
      data.sprite.oy = data.sprite.bitmap.height / 2
    else
      raise Itefu::Exception::Unreachable
    end
    
    anime = Itefu::Animation::KeyFrame.new
    anime.default_target = data.sprite
    anime.instance_eval {
      add_key 0, :x, nil
      add_key 0, :y, nil
      add_key 0, :zoom_x, nil
      add_key 0, :zoom_y, nil
      add_key 0, :opacity, nil
      add_key 0, :blend_type, blend_type, step

      add_key duration, :x, x
      add_key duration, :y, y
      add_key duration, :zoom_x, zoom_x
      add_key duration, :zoom_y, zoom_y
      add_key duration, :opacity, opacity
    }
    play_animation([index, :move], anime)
  end
  
  # 回転する
  def rotate(index, angle)
    return unless shown?(index)

    @data_container[index].angle_velocity = angle
  end
  
  # トーンを変更する
  def change_tone(index, tone, duration)
    return unless shown?(index)

    data = @data_container[index]
   
    anime = Itefu::Animation::KeyFrame.new
    anime.default_target = data.sprite.tone
    anime.instance_eval {
      add_key 0, :red, nil
      add_key 0, :green, nil
      add_key 0, :blue, nil
      add_key 0, :gray, nil

      add_key duration, :red, tone.red
      add_key duration, :green, tone.green
      add_key duration, :blue, tone.blue
      add_key duration, :gray, tone.gray
    }
    play_animation([index, :tone], anime)
  end
  
private

  def update_rotation
    @data_container.each_value do |data|
      if data.angle_velocity != 0
        # @note オリジナルの実装に合わせる
        data.sprite.angle += (data.angle_velocity / 2.0)
        data.sprite.angle %= Itefu::Utility::Math::Degree::FULL_CIRCLE
      end
    end
  end

end

=begin
  マップに表示する「遠景」用のユニット 
=end
class Map::Unit::Parallax < Map::Unit::Base
  def default_priority; Map::Unit::Priority::PARALLAX; end
  include Itefu::Resource::Loader
  Z_INDEX = -100    # RGSS3定義値

  def on_suspend
    {
      :name => @name,
      :loop_x => @loop_x,
      :loop_y => @loop_y,
      :sx => @sx,
      :sy => @sy,
      :ox => @plane && @plane.ox,
      :oy => @plane && @plane.oy,
    }
  end

  def on_resume(context)
    show(context[:name], context[:loop_x], context[:loop_y], context[:sx], context[:sy])
    if @plane
      @plane.ox = context[:ox]
      @plane.oy = context[:oy]
    end
  end
  
  def on_initialize(viewport, name = nil, loop_x = false, loop_y = false, sx = 0, sy = 0)
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, viewport)
    @plane = Itefu::Rgss3::Plane.new(@viewport)
    @plane.z = Z_INDEX
    show(name, loop_x, loop_y, sx, sy)
  end
  
  def on_finalize
    if @plane
      @plane.dispose
      @plane = nil
    end
    @viewport = Itefu::Rgss3::Resource.swap(@viewport, nil)
    release_all_resources
    @res_id = nil
  end
  
  def on_update
    return unless @plane
    change_parallax
    update_auto_scroll
  end
  
  # 表示を予約する
  # @note 連続で指定したとき何度もリソースを読み込まないよう遅延ロードする
  def show(name, loop_x, loop_y, sx, sy)
    @dirty = true
    @name = name
    @loop_x = loop_x
    @loop_y = loop_y
    @sx = sx
    @sy = sy
  end
  
  # 遠景を消す
  # @note 表示とは異なり即座に消す
  def hide
    @name = nil
    @plane.bitmap = nil
    release_resource(@res_id) if @res_id
    @res_id = nil
  end
  
  def update_scroll(ox, oy)
    # @todo プレイヤー移動に合わせたスクロールの対応
    # ループするマップでox/oyが飛ぶとき単純に計算するとおかしくなる
    # ループを考慮しつつox/oyのdeltaを計算してその分を加算するしかないか
    # @plane.ox = ox / 2
    # @plane.oy = oy / 2
  end
  
  
private

  # 予約された遠景を読み込んで設定する
  def change_parallax
    return unless @dirty
    if @name.nil? || @name.empty?
      hide
    else
      release_resource(@res_id) if @res_id
      @res_id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::PARALLAXES_s % @name)
      @plane.bitmap = resource_data(@res_id)
    end
    @dirty = false
  end
  
  def update_auto_scroll
    return if @dirty
    return unless bitmap = @plane.bitmap
    @plane.ox = Itefu::Utility::Math.loop_size(bitmap.width,  @plane.ox + @sx)
    @plane.oy = Itefu::Utility::Math.loop_size(bitmap.height, @plane.oy + @sy)
  end
  
end

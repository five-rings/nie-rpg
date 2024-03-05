=begin  
=end
module Aspect::Profiler

  def self.enable_map
    splittimer = Itefu::Debug::SplitTimer.new("map-instance")

    Itefu::Aspect.add_advice Map::Instance, :load_chara_resources do |caller|
      splittimer.start("----- map.#{caller.this.map_id} -----")
      caller.()
      splittimer.check("load_chara_resources")
    end

    Itefu::Aspect.add_advice Map::Instance, :load_tileset_resources do |caller|
      caller.()
      splittimer.check("load_tileset_resources")
    end

    Itefu::Aspect.add_advice Map::Instance, :setup_units do |caller|
      caller.()
      splittimer.check("setup_units")
    end
  end

end
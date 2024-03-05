=begin
  
=end
class Map::MapObject::Route
  include Itefu::Rgss3::Definition::Event::Route::Command
  attr_accessor :map_instance
  attr_reader :route
  attr_reader :program_counter
  
  Direction = Itefu::Rgss3::Definition::Direction
  
  def marshal_dump
    # @note 復帰時に map_instance を再設定しなければならない
    instance = @map_instance
    @map_instance = nil
    data = {}
    self.instance_variables.each do |sym|
      data[sym] = self.instance_variable_get(sym)
    end
    @map_instance = instance
    data
  end
  
  def marshal_load(object)
    object.each do |key, val|
      self.instance_variable_set(key, val)
    end
  end
  
  def repeat?
    route.repeat
  end
  
  def skippable?
    route.skippable
  end
  
  def wait?
    route.wait
  end
  
  def finished?
    @finished
  end
  
  def executable?
    @wait_count <= 0
  end
  
  def list
    route.list
  end
  
  def change_switch(id, value)
    Map::SaveData.change_switch(id, value)
  end

  def change_self_switch(map_id, event_id, id, value)
    Map::SaveData.change_self_switch(map_id || map_instance.map_id, event_id || @mapobject_id, id, value)
  end

  # このルートを実行しているMapObject  
  def mapobject
    @map_instance.mapobject(@mapobject_id)
  end
  
  # 「プレイヤーのほうを向く」時に参照するMapObject
  def player_object
    @map_instance.mapobject(@player_object_id)
  end
  
  def initialize(map_instance, route, subject, object)
    @map_instance = map_instance
    @finished = false
    @wait_count = 0
    @route = route
    @program_counter = 0
    @mapobject_id = subject.unit_id
    @player_object_id = object.unit_id
  end

  def step_to_next_command
    @program_counter += 1
    if program_counter >= list.size
      process_route_finish
    end
  end  

  def current_movecommand
    list[program_counter]
  end
  
  def update
    if executable?
      process_movecommand
    else
      @wait_count -= 1
    end
  end
  
  def process_movecommand
    return unless current_movecommand
    code = current_movecommand.code
    params = current_movecommand.parameters
    step_to_next_command
    
    succeeded = true
    case code
    when FINISH;                process_route_finish
    when MOVE_DOWN;             succeeded = mapobject.move(Direction::DOWN)
    when MOVE_LEFT;             succeeded = mapobject.move(Direction::LEFT)
    when MOVE_RIGHT;            succeeded = mapobject.move(Direction::RIGHT)
    when MOVE_UP;               succeeded = mapobject.move(Direction::UP)
    when MOVE_LEFT_DOWN;        succeeded = mapobject.move(Direction::LEFT_DOWN)
    when MOVE_RIGHT_DOWN;       succeeded = mapobject.move(Direction::RIGHT_DOWN)
    when MOVE_LEFT_UP;          succeeded = mapobject.move(Direction::LEFT_UP)
    when MOVE_RIGHT_UP;         succeeded = mapobject.move(Direction::RIGHT_UP)
    when MOVE_RANDOM;           succeeded = mapobject.move_random
    when MOVE_TOWARD_PLAYER;    succeeded = mapobject.move_toward_mapobject(player_object)
    when MOVE_AWAY_FROM_PLAYER; succeeded = mapobject.move_away_from_mapobject(player_object)
    when MOVE_FORWARD;          succeeded = mapobject.move_forward
    when MOVE_BACK;             succeeded = mapobject.move_backward
    when JUMP;                  mapobject.jump(params[0], params[1])
    when WAIT;                  @wait_count = params[0] - 1
    when TURN_DOWN;             mapobject.turn(Direction::DOWN)
    when TURN_LEFT;             mapobject.turn(Direction::LEFT)
    when TURN_RIGHT;            mapobject.turn(Direction::RIGHT)
    when TURN_UP;               mapobject.turn(Direction::UP)
    when TURN_90_RIGHT;         mapobject.turn_90_right
    when TURN_90_LEFT;          mapobject.turn_90_left
    when TURN_180;              mapobject.turn_180
    when TURN_90_RANDOM 
      case rand(2)
      when 1
        mapobject.turn_90_right
      else
        mapobject.turn_90_left
      end
    when TURN_RANDOM;           mapobject.turn_random
    when TURN_TOWARD_PLAYER;    mapobject.turn_toward_mapobject(player_object)
    when TURN_AWAY_FROM_PLAYER; mapobject.turn_away_from_mapobject(player_object)
    when SWITCH_ON;             change_switch(params[0], true) 
    when SWITCH_OFF;            change_switch(params[0], false)
    when CHANGE_MOVE_SPEED;     mapobject.move_speed = params[0]
    when CHANGE_MOVE_FREQUENCY; mapobject.move_frequency = params[0]
    when WALK_ANIME_ON;         mapobject.walk_anime = true
    when WALK_ANIME_OFF;        mapobject.walk_anime = false
    when STEP_ANIME_ON;         mapobject.step_anime = true
    when STEP_ANIME_OFF;        mapobject.step_anime = false
    when DIRECTION_FIX_ON;      mapobject.direction_fixed = true
    when DIRECTION_FIX_OFF;     mapobject.direction_fixed = false
    when THROUGH_ON;            mapobject.passable = true
    when THROUGH_OFF;           mapobject.passable = false
    when TRANSPARENT_ON;        mapobject.transparent = true
    when TRANSPARENT_OFF;       mapobject.transparent = false
    when CHANGE_GRAPHIC;          mapobject.change_graphic(params[0], params[1])
    when CHANGE_OPACITY;          mapobject.opacity = params[0]
    when CHANGE_BLENDING_METHOD;  mapobject.blending_method = params[0]
    when PLAY_SE;                 params[0].play
    when SCRIPT;                  eval(params[0])
    end
    
    @program_counter -= 1 unless skippable? || succeeded
  end
  
private

  def process_route_finish
    if repeat?
      @program_counter = 0
    else
      @finished = true
    end
  end

end

=begin
=end
module Map

  module WalkSpeed
    NORMAL = :normal
    SNEAK  = :sneak
    DASH   = :dash
  end
 
  module ExitCode
    CLOSE = :close
    LOAD = :load
    NEW_GAME = :new_game
    START_BATTLE = :battle
    OPEN_MENU = :menu
    OPEN_SYNTH = :synth
    OPEN_HELP = :help
    OPEN_SAVE = :save
    OPEN_PREFERENCE = :preference
    SELECT_ITEM = :item
  end
  
  module Viewport
    include ::Viewport::Map
  end
  
  # 隊列表示の設定を行う
  def self.setup_followers(resuming_context, to_show_followers)
    mycontext = resuming_context[:manager] ||= {}
    mycontext = mycontext[Map::Unit::Player.unit_id] ||= {}
    Map::Unit::Player.setup_followers(mycontext, to_show_followers)
  end
  
  # プレイヤーの初期設定を行う
  def self.setup_player_graphic(resuming_context, actor_id)
    actor = Application.database.actors.rawdata[actor_id]
    ITEFU_DEBUG_ASSERT(RPG::Actor === actor, "actor is not RPG::Actor, actual: #{actor.class}")
    mycontext = resuming_context[:manager] ||= {}
    mycontext = mycontext[Map::Unit::Player.unit_id] ||= {}
    Map::Unit::Player.setup_player_graphic(mycontext, actor.character_name, actor.character_index)
  end
  
  # プレイヤーの位置を設定する
  def self.setup_start_position(resuming_context, cell_x, cell_y, direction = nil)
    direction ||= Itefu::Rgss3::Definition::Direction::DOWN
    mycontext = resuming_context[:manager] ||= {}
    mycontext = mycontext[Map::Unit::Player.unit_id] ||= {}
    Map::Unit::Player.setup_start_position(mycontext, cell_x, cell_y, direction)
  end

end

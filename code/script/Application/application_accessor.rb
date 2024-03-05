=begin
  各種アクセッサインターフェイス
=end
module Application::Accessor
  
  module GameData
    def reset(ending_type = nil)
      Application.savedata_game.reset_for_restart
      Application.savedata_game.flags.ending_type = ending_type if ending_type
    end

    def flags
      Application.savedata_game.flags
    end

    def reset_to_quit
      Application.savedata_game.system.embodied = false
    end

    def playing_time
      Application.savedata_game.header.playing_time
    end

    def system
      Application.savedata_game.system
    end

    def map
      Application.savedata_game.map
    end

    def party
      Application.savedata_game.party
    end

    def inventory
      Application.savedata_game.inventory
    end

    def important
      Application.savedata_game.important
    end

    def repository
      Application.savedata_game.repository
    end

    def reward
      Application.savedata_game.reward
    end

    def actor(id)
      Application.savedata_game.actors[id]
    end

    def reset_actor(id)
      Application.savedata_game.actors.reset_actor(id)
    end

    def change_if_show_map_name(to_show)
      Application.savedata_game.map.to_show_name = to_show
    end

    def collection
      Application.savedata_game.collection
    end

    def number_of_item(item, curio = true)
      c = Application.savedata_game.inventory.number_of_item(item)
      c += Application.savedata_game.important.number_of_item(item) if curio
      Application.savedata_game.actors.actors.each_value do |actor|
        c += actor.number_of_equipments(item)
      end if RPG::EquipItem === item
      c
    end

    def encounter_half?
      Application.savedata_game.actors.encounter_half?
    end

    def encounter_none?
      Application.savedata_game.actors.encounter_none?
    end

    def gold_double?
      Application.savedata_game.actors.gold_double?
    end

    def drop_item_double?
      Application.savedata_game.actors.drop_item_double?
    end

    def save_map(map)
      save_map = Application.savedata_game.map
      save_map.map_id = map.active_map_id || map.map_id_to_transfer

      save_map.resuming_context.clear
      map.save_to_resuming_context(save_map.resuming_context)

      instance = map.active_instance
      map_name = instance.map_data.display_name
      save_map.map_name = map_name unless map_name.empty?

      save_map.fairy_map_id = instance.fairy_map_id
    end

    def save_game(index = nil)
      Application.instance.save_savedata(index)
    end

    def game_data_exists?(index = nil)
      SaveData.game_data_exists?(index)
    end

    def clear_game_temp
      SaveData.clear_save_game_temp
    end

    def duplicate_game_data(index = nil)
      SaveData.duplicate_game_data(index)
    end
    extend self
  end

  module SystemData
    def collection
      Application.savedata_system.collection
    end
    def offering
      Application.savedata_system.offering
    end
    def flags
      Application.savedata_system.flags
    end
    extend self
  end

  module Flags
    # スイッチの状態を取得する
    def switch(id)
      Application.savedata_game.flags.switches[id]
    end
    
    # スイッチのフラグを反転させる
    def flip_switch(id)
      Application.savedata_game.flags.switches[id] = Application.savedata_game.flags.switches[id].!
    end

    # スイッチの状態を変更する
    def change_switch(id, value)
      Application.savedata_game.flags.switches[id] = value
    end

    
    # セルフスイッチの状態を取得する
    def self_switch(map_id, event_id, id)
      Application.savedata_game.flags.self_switches[map_id, event_id, id]
    end
    
    def flip_self_switch(map_id, event_id, id)
      Application.savedata_game.flags.self_switches[map_id, event_id, id] = 
        Application.savedata_game.flags.self_switches[map_id, event_id, id].!
    end
    
    # セルフスイッチの状態を変更する
    def change_self_switch(map_id, event_id, id, value)
      Application.savedata_game.flags.self_switches[map_id, event_id, id] = value
    end
    
    
    # 変数の値を取得する
    def variable(id)
      Application.savedata_game.flags.variables[id]
    end
    
    # 変数の値を変更する
    def change_variable(id, value)
      Application.savedata_game.flags.variables[id] = value
    end

    extend self
  end 
 
  module Input
    # @params [Itefu::Rgss3::Input::Code] button_id ボタンの識別子
    def pressing?(code)
      return false unless input = Application.input
      return false unless mean = ::Input.code_to_mean(code)
      input.pressed?(mean)
    end
  end

end

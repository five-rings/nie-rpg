=begin
  テスト戦闘画面 
=end
class Scene::Debug::Battle < Itefu::Scene::Base
  
  EQUIP_POS = [
    Definition::Game::Equipment::Type::RIGHT_HAND,
    Definition::Game::Equipment::Type::LEFT_HAND,
    Definition::Game::Equipment::Type::HEAD,
    Definition::Game::Equipment::Type::BODY,
    Definition::Game::Equipment::Type::ACCESSORY_A,
  ]
  EQUIP_TYPE = [
    RPG::Weapon.kind,
    RPG::Armor.kind,
    RPG::Armor.kind,
    RPG::Armor.kind,
    RPG::Armor.kind,
  ]
  
  def on_initialize
    fade = Application.fade
    fade.transit(10) unless fade.faded_out?

    gamedata = Application.load_game { SaveData.new_game }
    gamedata.system.to_save = false if gamedata
    system = Application.database.system.rawdata
    set_test_battlers
    push_scene(Scene::Game::Battle,
      system.test_troop_id,
      true,
      true,
      system.battleback1_name,
      system.battleback2_name
    )
  end
  
  def on_resume(prev_scene)
    quit
  end
  
private

  def set_test_battlers
    weapons = Application.database.weapons
    armors = Application.database.armors
    save_actors = Application.savedata_game.actors
    save_party = Application.savedata_game.party
    save_party.members.clear

    system = Application.database.system.rawdata
    system.test_battlers.each do |battler|
      save_party.add_member(battler.actor_id)
      actor = save_actors.add_actor(battler.actor_id)
      actor.add_level(battler.level - 1) if battler.level > 1
      actor.recover_all
      battler.equips.each_with_index do |id, index|
        item = case EQUIP_TYPE[index]
               when RPG::Weapon.kind
                 weapons[id]
               when RPG::Armor.kind
                 armors[id]
               end
        actor.equip(EQUIP_POS[index], item) if item
      end
    end 
  end

end

add "setup"

import "itefu"

add "buildconfig"
add "buildconfig_debug", :debug
add "buildconfig_release", :release
add "filename"
add "font"

# Debug
add "debug/debug_define"
add <<-EOS, :debug
  debug/debug
  debug/debug_utility
  debug/debug_diagnosis
EOS

# Aspect
add <<-EOS, :debug
  aspect/aspect
  aspect/aspect_profiler
EOS

# Config
add <<-EOS
  config/config
  config/config_myconfig
  config/config_exptable
  config/config_params
EOS

# Win32
add <<-EOS
  win32/win32
  win32/win32_registry
  win32/win32_locale
EOS

# Extention
add "audio"

# RPG
add <<-EOS
  rpg/rpg_baseitem
  rpg/rpg_usableitem
  rpg/rpg_skill
  rpg/rpg_item
  rpg/rpg_equipitem
  rpg/rpg_weapon
  rpg/rpg_armor
  rpg/rpg_event
  rpg/rpg_state
  rpg/rpg_class
  rpg/rpg_class_learning
  rpg/rpg_enemy
  rpg/rpg_actor
EOS

# Definition
add <<-EOS
  definition/definition
  definition/definition_game
  definition/definition_game_ai
EOS

# Sound
add "sound"

# Viewport
add "viewport"

# Language
add <<-EOS
  language/language
  language/message
EOS

# Database
add <<-EOS
  database/database
  database/database_table
  database/database_table_baseitem
  database/database_table_system
  database/database_table_actors
  database/database_table_enemies
  database/database_table_classes
  database/database_table_items
  database/database_table_weapons
  database/database_table_armors
  database/database_table_skills
  database/database_table_states
EOS

# SaveData
add <<-EOS
  savedata/savedata
  savedata/system/savedata_system
  savedata/system/savedata_system_input
  savedata/system/savedata_system_collection
  savedata/system/savedata_system_preference
  savedata/game/savedata_game
  savedata/game/savedata_game_preview
  savedata/game/savedata_game_itemdata
  savedata/game/savedata_game_base
  savedata/game/savedata_game_header
  savedata/game/savedata_game_flags
  savedata/game/savedata_game_system
  savedata/game/savedata_game_map
  savedata/game/savedata_game_inventory
  savedata/game/savedata_game_important
  savedata/game/savedata_game_repository
  savedata/game/savedata_game_reward
  savedata/game/savedata_game_collection
  savedata/game/savedata_game_actors
  savedata/game/actor/savedata_game_actor
  savedata/game/actor/savedata_game_actor_level
  savedata/game/actor/savedata_game_actor_equipment
  savedata/game/actor/savedata_game_actor_state
  savedata/game/actor/savedata_game_actor_buff
  savedata/game/actor/savedata_game_actor_feature
  savedata/game/actor/savedata_game_actor_status
  savedata/game/actor/savedata_game_actor_impl
  savedata/game/party/savedata_game_party
  savedata/game/party/savedata_game_party_money
  savedata/game/party/savedata_game_party_passiveskill
  savedata/game/party/savedata_game_party_impl
EOS

# Input
add <<-EOS
  input/input
  input/input_manager
EOS

# SceneGraph
add <<-EOS
  scenegraph/scenegraph
  scenegraph/scenegraph_mapobject
  scenegraph/scenegraph_balloon
  scenegraph/scenegraph_cursor
EOS

# Layout
add <<-EOS
  layout/layout
  layout/layout_constant
  layout/layout_view
  layout/viewmodel/layout_viewmodel
  layout/viewmodel/layout_viewmodel_dialog
  layout/viewmodel/layout_viewmodel_dialog_chara
  layout/viewmodel/layout_viewmodel_charamenu
  layout/control/layout_control
  layout/control/layout_control_root
EOS
add "layout/control/layout_control_root_debug", :debug
add <<-EOS
  layout/control/layout_control_importer
  layout/control/layout_control_empty
  layout/control/layout_control_formatstring
  layout/control/layout_control_captioneditem
  layout/control/layout_control_cursor
  layout/control/layout_control_dial
  layout/control/layout_control_gauge
  layout/control/layout_control_scrollbar
  layout/control/layout_control_textarea
  layout/control/layout_control_cabinetinverse
  layout/control/layout_control_autoscroll
EOS

# Animation
add <<-EOS
  animation/animation
  animation/animation_manager
  animation/animation_decide
  animation/animation_escape
  animation/animation_damage
  animation/animation_winning
EOS

# BehaviorTree
add <<-EOS
  behaviortree/behaviortree
  behaviortree/node/behaviortree_node
  behaviortree/behaviortree_rootbase
EOS

# Application
add <<-EOS
  application
  application/application_accessor
EOS

# Event
add <<-EOS
  event/event
  event/event_interpreter
  event/event_interpreter_map
  event/event_interpreter_battle
EOS

# Game
add <<-EOS
  game/game
  game/game_agency
  game/game_encounter
  game/unit/game_unit
  game/unit/game_unit_picture
  game/unit/game_unit_message
  game/unit/gimmick/game_unit_gimmick
  game/unit/gimmick/game_unit_gimmick_weather
  game/unit/gimmick/game_unit_gimmick_rain
  game/unit/gimmick/game_unit_gimmick_snow
  game/unit/gimmick/game_unit_gimmick_storm
EOS

# Map
add <<-EOS
  map/map
  map/map_manager
  map/map_manager_state
  map/map_input
  map/map_view
  map/map_viewmodel
  map/map_savedata
  map/map_structure
  map/map_path
  map/map_instance
  map/map_instance_state
  map/mapobject/map_mapobject
  map/mapobject/map_mapobject_movable
  map/mapobject/map_mapobject_drawable
  map/mapobject/map_mapobject_route
  map/mapobject/map_mapobject_companion
  map/mapobject/map_mapobject_behaviortree
  map/behavior/map_behavior
  map/unit/map_unit
  map/unit/map_unit_base
  map/unit/map_unit_composite
  map/unit/map_unit_system
  map/unit/map_unit_picture
  map/unit/map_unit_parallax
  map/unit/ui/map_unit_ui
  map/unit/ui/map_unit_ui_message
  map/unit/ui/map_unit_ui_shop
  map/unit/ui/map_unit_ui_guide
  map/unit/gimmick/map_unit_gimmick
  map/unit/gimmick/map_unit_gimmick_dark
  map/unit/gimmick/map_unit_gimmick_fog
  map/unit/map_unit_mapobject
  map/unit/map_unit_player
  map/unit/map_unit_follower
  map/unit/map_unit_events
  map/unit/map_unit_event
  map/unit/map_unit_scroll
  map/unit/map_unit_pointer
  map/unit/map_unit_tilemap
  map/unit/map_unit_interpreter
  map/unit/map_unit_sound
EOS

# Battle
add <<-EOS
  battle/battle
  battle/battle_manager
  battle/battle_manager_action
  battle/battle_manager_state
  battle/battle_savedata
  battle/battle_party
  battle/battle_troop
  battle/unit/battle_unit
  battle/unit/battle_unit_base
  battle/unit/battle_unit_composite
  battle/unit/battle_unit_picture
  battle/unit/battle_unit_gimmick
  battle/unit/battle_unit_field
  battle/unit/battle_unit_status
  battle/unit/battle_unit_action
  battle/unit/battle_unit_command
  battle/unit/battle_unit_voice
  battle/unit/battle_unit_battler
  battle/unit/battle_unit_party
  battle/unit/battle_unit_actor
  battle/unit/battle_unit_troop
  battle/unit/battle_unit_enemy
  battle/unit/battle_unit_damage
  battle/unit/battle_unit_interpreter
  battle/unit/battle_unit_message
  battle/unit/battle_unit_result
EOS

# Scenes
add <<-EOS
  scene/scene
  scene/scene_root
  scene/game/scene_game
  scene/game/scene_game_base
  scene/game/scene_game_saveload
  scene/game/boot/scene_game_boot
  scene/game/boot/scene_game_boot_logo
  scene/game/scene_game_map
  scene/game/menu/scene_game_menu
  scene/game/menu/scene_game_menu_top
  scene/game/menu/scene_game_menu_save
  scene/game/menu/scene_game_menu_item
  scene/game/menu/scene_game_menu_skill
  scene/game/menu/scene_game_menu_equipment
  scene/game/menu/scene_game_menu_episode
  scene/game/menu/scene_game_menu_synth
  scene/game/menu/scene_game_menu_itemselect
  scene/game/scene_game_help
  scene/game/scene_game_preference
  scene/game/scene_game_overview
  scene/game/scene_game_battle
  scene/game/title/scene_game_title
  scene/game/title/scene_game_title_map
  scene/game/title/scene_game_title_logo
  scene/game/title/scene_game_title_end
  scene/game/title/scene_game_title_load
EOS
add <<-EOS, :debug
  scene/debug/scene_debug
  scene/debug/scene_debug_root
  scene/debug/scene_debug_battle
  scene/debug/menu/scene_debug_menu
  scene/debug/menu/scene_debug_menu_loadgame
  scene/debug/menu/scene_debug_menu_layout
  scene/debug/menu/scene_debug_menu_text
  scene/debug/menu/scene_debug_menu_description
  scene/debug/menu/scene_debug_menu_skillanimation
EOS

add "main"

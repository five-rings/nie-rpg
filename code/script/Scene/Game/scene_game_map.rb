=begin
  マップ画面  
=end
class Scene::Game::Map < Itefu::Scene::Base
  
  module ExitCode
    include Map::ExitCode
    OPEN_OVERVIEW = :ovewview
  end
  def exit_code; @map.exit_code; end
  def exit_param; @map.exit_param; end

  module Param
    Event = Struct.new(:item)
    Item = Struct.new(:item)
  end
  
#ifdef :ITEFU_DEVELOP
  module DebugInput
    SCROLL = :scroll
    BE_GHOST = :ghost
    GO_TO_DEBUG_MAP = :debug_map
    DEBUG_MONEY = :debug_money
    DEBUG_ITEM = :debug_item
    TOGGLE_TEST_EVENTS = :debug_event
    DEBUG_GIMMICK = :debug_gimmick
    OPEN_ENCOUNTER_CHECK = :debug_encounter
    SAVE_TEMP = :debug_save
    TONE_COLOR = :debug_tone_color
    TONE_GREY = :debug_tone_grey
  end
#endif

  def able_to_open_menu?
    Application.savedata_game.system.to_open_menu
  end

  def able_to_open_help?
    Application.savedata_game.system.to_open_menu
  end

  def able_to_open_preference?
    Application.savedata_game.system.to_open_menu
  end

  def on_initialize(param = nil)
    case param
    when Battle::Result
      result = param if param.event?
    when Param::Event
      event_item = param.item
    when Param::Item
      result = param.item
    when ExitCode::LOAD
      @quick_loaded = true
    end

    Application.input.check_joypad

    lang_msg = Application.language.load_message(:map)
    lang_ce = Application.language.load_message(Filename::Language::COMMON_EVENTS)
    view = Application.resident_resource(:map_view, Map::View)
    save_map = Application.savedata_game.map
#ifdef :ITEFU_DEVELOP
    setup_debug_input
#endif
    setup_keycommands
    @map = Map::Manager.new(save_map.resuming_context, view).
                        config_result(result).
                        config_input(method(:input)).
                        config_fade(Application.fade).
                        config_sound(Itefu::Sound).
                        config_database(Application.database).
                        config_lang(lang_msg, lang_ce).
                        start(save_map.map_id)
    add_external_events(event_item) if event_item

    while notice = Application.instance.map_notices.shift
      @map.push_notice(notice)
    end

    Application.focus.push(view.focus)
    make_sure_to_fade_out(0)
  end
  
#ifdef :ITEFU_DEVELOP
  def setup_debug_input
    input = Application.input
    semantic = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32).instance_eval do
      define(DebugInput::SCROLL, Itefu::Input::Win32::Code::VK_TAB)
      define(DebugInput::BE_GHOST,  Itefu::Input::Win32::Code::VK_MENU)
      define(DebugInput::GO_TO_DEBUG_MAP,  Itefu::Input::Win32::Code::VK_F5)
      define(DebugInput::DEBUG_MONEY,  Itefu::Input::Win32::Code::VK_F8)
      define(DebugInput::DEBUG_ITEM,  Itefu::Input::Win32::Code::VK_F7)
      define(DebugInput::OPEN_ENCOUNTER_CHECK, Itefu::Input::Win32::Code::VK_F4)
      define(DebugInput::SAVE_TEMP,  Itefu::Input::Win32::Code::VK_F9)
      define(DebugInput::TOGGLE_TEST_EVENTS,  Itefu::Input::Win32::Code::VK_DELETE)
      define(DebugInput::DEBUG_GIMMICK,  Itefu::Input::Win32::Code::VK_END)
      define(DebugInput::TONE_COLOR,  Itefu::Input::Win32::Code::VK_OEM_4)  # [ key
      define(DebugInput::TONE_GREY,  Itefu::Input::Win32::Code::VK_OEM_6)   # ] key
      self
    end
    input.add_semantics(:map_debug, semantic)
  end
#endif

  def add_external_events(item)
    dbc = Application.database.common_events
    item.effects.each do |effect|
      next unless effect.code == Itefu::Rgss3::Definition::Skill::Effect::COMMON_EVENT
      if event = dbc[effect.data_id]
        @map.system_unit.reserve_event(event)
      end
    end
  end

  def make_sure_to_fade_out(dout = 15)
    fade = Application.fade
    fade.fade_color(Itefu::Color.Black, dout, 15) unless fade.faded_out?
  end
  
  # マップのユニットの状態を保存する
  def save_map_context
    Map::SaveData::GameData.save_map(@map)
  end
  
  # マップ画面のスナップショットを作成する
  def create_map_snapshot
    # 不要なものを消す
    @map.viewports[:hud].visible = false
    fade = Application.fade
    fade.viewport.visible = false
    Application.animation.viewport.visible = false

#ifdef :ITEFU_DEVELOP
    # デバッグ表示を消してスナップショットの作成
    bitmap = Application.suspend_debug_draw {
      Application.create_snapshot
    }
#else
    # スナップショットの作成
    bitmap = Application.create_snapshot
#endif

    # 消した物を戻す
    @map.viewports[:hud].visible = true
    Application.animation.viewport.visible = true
    fade.viewport.visible = true

    bitmap
  end

  def on_finalize
    input = Application.input
    input.check_joypad
#ifdef :ITEFU_DEVELOP
    input.remove_semantics(:map_debug)
#endif
    unless Application.rgss_reset?
      create_map_snapshot
      # load or save context
      case @map.exit_code
      when ExitCode::NEW_GAME
        # new game
        Application.load_game { SaveData.new_game }
        Application.savedata_game.system.embodied = true
      when ExitCode::LOAD
        # load slot
        index = Definition::Game::Save::QUICK_SAVE_LOAD_INDEX
        if SaveData.game_data_exists?(index)
          Application.load_game { SaveData.load_game(index) }
        end
      when ExitCode::CLOSE
        # close the game
        if Application.savedata_game.system.embodied
          save_map_context
        end
      else
        # to other menu
        save_map_context
      end
    end
    Application.focus.pop
    @map.finalize
    # @map = nil
    Application.language.release_message(Filename::Language::COMMON_EVENTS)
    Application.language.release_message(:map)
  end
  
  def on_update
    if @quitted
      fade = Application.fade
      close if fade.faded_out? && fade.fading?.!
    else
      if @map.running?
        if @quick_loaded
          @map.push_notice(:quick_loaded)
          @quick_loaded = false
        end
        @map.update
#ifdef :ITEFU_DEVELOP
        if input = Application.input
          if input.triggered?(DebugInput::SAVE_TEMP)
            save_map_context
            Application.savedata_game.system.to_save = true
            Application.instance.save_savedata
            raise RGSSReset
          end
        end
#endif
      else
        @quitted = true
        case @map.exit_code
        when ExitCode::START_BATTLE 
          fade = Application.fade
          fade.fade_out_with_transition(15, Itefu::Rgss3::Filename::Graphics::BATTLE_START) unless fade.faded_out?
        else
          if Application.savedata_game.system.embodied
            make_sure_to_fade_out 
          else
            make_sure_to_fade_out(30)
          end
        end unless Application.rgss_reset?
      end
    end
#ifndef :ITEFU_DEVELOP
  rescue RGSSReset
    raise
  rescue Exception
    # save crashing data
    save_map_context
    raise
#endif
  end
  
  def on_draw
    @map.draw if @map.running?
  end
  
  def setup_keycommands
    @commander = commander = Itefu::Input::Commander.new
#ifdef :ITEFU_DEVELOP
    # Scroll
    commander.new_command.
              add_stroke(Input::DECIDE, :triggered?, DebugInput::SCROLL).
              add_callback {|input, map|
                map.operate_scroll_map(nil)
              }
    commander.new_command.
              add_stroke(Input::LEFT, :pressed?, DebugInput::SCROLL).
              add_callback {|input, map|
                map.operate_scroll_map(Itefu::Rgss3::Definition::Direction::LEFT)
              }
    commander.new_command.
              add_stroke(Input::UP, :pressed?, DebugInput::SCROLL).
              add_callback {|input, map|
                map.operate_scroll_map(Itefu::Rgss3::Definition::Direction::UP)
              }
    commander.new_command.
              add_stroke(Input::RIGHT, :pressed?, DebugInput::SCROLL).
              add_callback {|input, map|
                map.operate_scroll_map(Itefu::Rgss3::Definition::Direction::RIGHT)
              }
    commander.new_command.
              add_stroke(Input::DOWN, :pressed?, DebugInput::SCROLL).
              add_callback {|input, map|
                map.operate_scroll_map(Itefu::Rgss3::Definition::Direction::DOWN)
              }
    # Tone
    commander.new_command.
              add_stroke(Input::UP, :triggered?, DebugInput::TONE_COLOR).
              add_callback {|input, map|
                gimmick = map.gimmick_unit
                vp = gimmick.instance_variable_get(:@viewport)
                tone = vp.tone
                tone.red += 10
                tone.green += 10
                tone.blue += 10
                ITEFU_DEBUG_OUTPUT_NOTICE tone
              }
    commander.new_command.
              add_stroke(Input::UP, :pressed?, DebugInput::TONE_COLOR)
    commander.new_command.
              add_stroke(Input::DOWN, :triggered?, DebugInput::TONE_COLOR).
              add_callback {|input, map|
                gimmick = map.gimmick_unit
                vp = gimmick.instance_variable_get(:@viewport)
                tone = vp.tone
                tone.red -= 10
                tone.green -= 10
                tone.blue -= 10
                ITEFU_DEBUG_OUTPUT_NOTICE tone
              }
    commander.new_command.
              add_stroke(Input::DOWN, :pressed?, DebugInput::TONE_COLOR)
    commander.new_command.
              add_stroke(Input::UP, :triggered?, DebugInput::TONE_GREY).
              add_callback {|input, map|
                gimmick = map.gimmick_unit
                vp = gimmick.instance_variable_get(:@viewport)
                tone = vp.tone
                tone.gray += 10
                ITEFU_DEBUG_OUTPUT_NOTICE tone
              }
    commander.new_command.
              add_stroke(Input::UP, :pressed?, DebugInput::TONE_GREY)
    commander.new_command.
              add_stroke(Input::DOWN, :triggered?, DebugInput::TONE_GREY).
              add_callback {|input, map|
                gimmick = map.gimmick_unit
                vp = gimmick.instance_variable_get(:@viewport)
                tone = vp.tone
                tone.gray -= 10
                ITEFU_DEBUG_OUTPUT_NOTICE tone
              }
    commander.new_command.
              add_stroke(Input::DOWN, :pressed?, DebugInput::TONE_GREY)
    # Dark
    commander.new_command.
              add_stroke(Input::LEFT, :triggered?, DebugInput::TONE_COLOR).
              add_callback {|input, map|
                case gimmick = map.gimmick_unit.gimmick(:additional)
                when Map::Unit::Gimmick::Dark
                  sp = gimmick.instance_variable_get(:@sprite)
                  sp.opacity -= 0x10
                  ITEFU_DEBUG_OUTPUT_NOTICE "0x%0x" % sp.opacity
                end
              }
    commander.new_command.
              add_stroke(Input::LEFT, :pressed?, DebugInput::TONE_COLOR)
    commander.new_command.
              add_stroke(Input::RIGHT, :triggered?, DebugInput::TONE_COLOR).
              add_callback {|input, map|
                case gimmick = map.gimmick_unit.gimmick(:additional)
                when Map::Unit::Gimmick::Dark
                  sp = gimmick.instance_variable_get(:@sprite)
                  sp.opacity += 0x10
                  ITEFU_DEBUG_OUTPUT_NOTICE "0x%0x" % sp.opacity
                end
              }
    commander.new_command.
              add_stroke(Input::RIGHT, :pressed?, DebugInput::TONE_COLOR)
    commander.new_command.
              add_stroke(Input::LEFT, :triggered?, DebugInput::TONE_GREY).
              add_callback {|input, map|
                case gimmick = map.gimmick_unit.gimmick(:additional)
                when Map::Unit::Gimmick::Dark
                  sp = gimmick.instance_variable_get(:@sprite)
                  sp.opacity -= 0x1
                  ITEFU_DEBUG_OUTPUT_NOTICE "0x%0x" % sp.opacity
                end
              }
    commander.new_command.
              add_stroke(Input::LEFT, :pressed?, DebugInput::TONE_GREY)
    commander.new_command.
              add_stroke(Input::RIGHT, :triggered?, DebugInput::TONE_GREY).
              add_callback {|input, map|
                case gimmick = map.gimmick_unit.gimmick(:additional)
                when Map::Unit::Gimmick::Dark
                  sp = gimmick.instance_variable_get(:@sprite)
                  sp.opacity += 0x1
                  ITEFU_DEBUG_OUTPUT_NOTICE "0x%0x" % sp.opacity
                end
              }
    commander.new_command.
              add_stroke(Input::RIGHT, :pressed?, DebugInput::TONE_GREY)
    # To be Ghost
    commander.new_command.set_nonblocking(true).
              add_stroke(DebugInput::BE_GHOST, :triggered?).
              add_callback {|input, map|
                map.operate_be_ghost(true)
              }
    commander.new_command.set_nonblocking(true).
              add_stroke(DebugInput::BE_GHOST, :released?).
              add_callback {|input, map|
                map.operate_be_ghost(false)
              }
    # To gain money for test play
    commander.new_command.
              add_stroke(DebugInput::DEBUG_MONEY, :triggered?).
              add_callback {|input, map|
                if Application.savedata_game.party.money == Application.savedata_game.party.money_max
                  Application.savedata_game.party.add_money(
                    -Application.savedata_game.party.money_max
                  )
                else
                  Application.savedata_game.party.add_money(
                    Application.savedata_game.party.money_max
                  )
                end
                Itefu::Sound.play_shop_se
              }
    # To obtain basic items for test play
    commander.new_command.
              add_stroke(DebugInput::DEBUG_ITEM, :triggered?).
              add_callback {|input, map|
                # @magic to evoke the event to obtain items for test-play
                Application.savedata_game.flags.switches[21] = true
                Itefu::Sound.play_use_item_se
              }
    # To toggle test events
    commander.new_command.
              add_stroke(DebugInput::TOGGLE_TEST_EVENTS, :triggered?).
              add_callback {|input, map|
                # @magic to hide test events
                Application.savedata_game.flags.switches[22] = Application.savedata_game.flags.switches[22].!
                Itefu::Sound.play_evasion_se
              }
    # To remove additional gimmick
    commander.new_command.
              add_stroke(DebugInput::DEBUG_GIMMICK, :triggered?).
              add_callback {|input, map|
                map.gimmick_unit.change_additional_gimmick(:none)
              }
    # To open encounter checker
    commander.new_command.
              add_stroke(DebugInput::OPEN_ENCOUNTER_CHECK, :triggered?).
              add_callback {|input, map|
                map.operate_open_encounter_check
              }
    # To go to Debug Map
    commander.new_command.
              add_stroke(DebugInput::GO_TO_DEBUG_MAP, :triggered?).
              add_callback {|input, map|
                map.operate_go_to_debug_map
              }
#endif
    # Player's Actions
    commander.new_command.
              add_stroke(Input::CLICK, :triggered?).
              add_callback {|input, map|
                map.operate_click(input.position_x, input.position_y)
              }
    commander.new_command.
              add_stroke(Input::CLICK, :pressed?).
              add_callback {|input, map|
                map.operate_clicking(input.position_x, input.position_y)
              }
    commander.new_command.
              # 移動ボタンおしたまま決定できるようにnon-blockingにする
              set_nonblocking(true).
              add_stroke(Input::DECIDE, :triggered?).
              add_callback {|input, map|
                map.operate_decide
              }
    commander.new_command.
              add_stroke(Input::CANCEL, :triggered?).
              add_callback {|input, map|
                if able_to_open_menu?
                  Sound.play_menu_se
                  map.quit(ExitCode::OPEN_MENU)
                else
                  Sound.play_disabled_se
                end
              }
    commander.new_command.
              add_stroke(Input::OPTION, :triggered?).
              add_callback {|input, map|
                if able_to_open_help?
                  Sound.play_menu_se
                  map.quit(ExitCode::OPEN_HELP)
                else
                  Sound.play_disabled_se
                end
              }
    # Sneaking
    commander.new_command.set_nonblocking(true).
              add_stroke(Input::SNEAK, :triggered?).
              add_callback {|input, map|
                map.operate_sneak(true)
              }
    commander.new_command.set_nonblocking(true).
              add_stroke(Input::SNEAK, :released?).
              add_callback {|input, map|
                map.operate_sneak(false)
              }
    # Dashing
    commander.new_command.set_nonblocking(true).
              add_stroke(Input::DASH, :triggered?).
              add_callback {|input, map|
                map.operate_dash_on
              }
    # commander.new_command.set_nonblocking(true).
    #           add_stroke(Input::DASH, :pressed?).
    #           add_callback {|input, map|
    #             @dash_pressing = true
    #           }
    # commander.new_command.set_nonblocking(true).
    #           add_stroke(Input::DASH, :released?).
    #           add_callback {|input, map|
    #             @dash_pressing = false
    #           }
    # Quick Saving
    commander.new_command.
              add_stroke(Input::QUICK_SAVE, :triggered?).
              add_callback {|input, map|
                # セーブは他の通知が出ていても優先的に実行・通知する
                if ui = map.ui_unit
                  # セーブ禁止かチェック
                  if Application.savedata_game.system.to_save
                    map.quick_save { create_map_snapshot }
                    ui.show_notice(map.lang_message.text(:quick_saved))
                  else
                    ui.show_notice(map.lang_message.text(:save_prohibited))
                  end
                end
              }
    # Quick Loading
    commander.new_command.
              add_stroke(Input::QUICK_LOAD, :triggered?).
              add_callback {|input, map|
                index = Definition::Game::Save::QUICK_SAVE_LOAD_INDEX
                if SaveData.game_data_exists?(index)
                  map.quit_to_load
                else
                  if ui = map.ui_unit
                    ui.show_notice(map.lang_message.text(:no_quick_load_data))
                  end
                end
              }
    # reset to change lang
    commander.new_command.
              add_stroke(Input::CONFIG, :triggered?).
              add_callback {|input, map|
                if able_to_open_preference?
                  Sound.play_menu_se
                  map.quit(ExitCode::OPEN_PREFERENCE)
                else
                  Sound.play_disabled_se
                end
              }
    # Player Moving
    commander.new_command.
              add_stroke(Input::LEFT, :triggered?).
              add_callback {|input, map|
                show_notice_shift_for_dash(map)
              }
    commander.new_command.
              add_stroke(Input::UP, :triggered?).
              add_callback {|input, map|
                show_notice_shift_for_dash(map)
              }
    commander.new_command.
              add_stroke(Input::RIGHT, :triggered?).
              add_callback {|input, map|
                show_notice_shift_for_dash(map)
              }
    commander.new_command.
              add_stroke(Input::DOWN, :triggered?).
              add_callback {|input, map|
                show_notice_shift_for_dash(map)
              }
    commander.new_command.
              add_stroke(Input::LEFT, :pressed?).
              add_callback {|input, map|
                map.operate_move_left
              }
    commander.new_command.
              add_stroke(Input::UP, :pressed?).
              add_callback {|input, map|
                map.operate_move_up
              }
    commander.new_command.
              add_stroke(Input::RIGHT, :pressed?).
              add_callback {|input, map|
                map.operate_move_right
              }
    commander.new_command.
              add_stroke(Input::DOWN, :pressed?).
              add_callback {|input, map|
                map.operate_move_down
              }
  end

  def show_notice_shift_for_dash(map)
    return unless @to_show_notice_shift_for_dash

    if (ui = map.ui_unit) && ui.notice_showing?.!
      # if @dash_pressing && map.player_dashing?.!
      if Application.input.pressed?(Input::DASH) && map.player_dashing?.!
        ui.show_notice(map.lang_message.text(:guide_for_dashing))
      end
    end
  end

  def input(map, inputable)
    prev = @inputable
    return unless @inputable = inputable
    return unless input = Application.input

    # 以前入力中に inputable.! になった可能性があるので、再度入力可能になった時点でresetする
    unless prev
      @commander.reset
      # @dash_pressing = false

      # イベント中にキーを離すと抜けてしまうため
      if Application.input.pressed?(Input::SNEAK)
        map.operate_sneak(true)
      else
        map.operate_sneak(false) unless map.player_dashing?
      end
    end

    map.operate_mouse_move(input.position_x, input.position_y)
    @commander.update(input, map)
  end

  alias :close :quit
  def quit
    if @map && @map.exit_code.nil?
      @map.quit(ExitCode::CLOSE)
    else
      close
    end
  end
  
end

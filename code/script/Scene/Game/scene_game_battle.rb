=begin
  戦闘画面
=end
class Scene::Game::Battle < Itefu::Scene::Base
  attr_reader :battle
  def result; @battle.result; end

#ifdef :ITEFU_DEVELOP
  module DebugInput
    FORCE_WIN    = :win
    FORCE_LOSE   = :lose
    FORCE_ESCAPE = :escape
  end
#endif

  def on_initialize(troop_id, escape, lose, floor_name, wall_name, event_battle = true, gimmick = nil)
    @losable = lose
#ifdef :ITEFU_DEVELOP
    setup_debug_input
#endif
    bgm = Application.savedata_game.system.battle_bgm
    lang_msg = Application.language.load_message(:battle)
    lang_trp = Application.language.load_message(Filename::Language::TROOP_TEXT_n % troop_id) rescue nil
    lang_ce = Application.language.load_message(Filename::Language::COMMON_EVENTS)
    @battle = Battle::Manager.new(troop_id, escape, lose, event_battle).
                              config_fade(Application.fade).
                              config_sound(Itefu::Sound).
                              config_lang(lang_msg, lang_trp, lang_ce).
                              config_database(Application.database).
                              start(floor_name, wall_name, bgm, gimmick)
    Application.focus.push(battle.focus)

    if img = Application.snapshot
      img.blur
    end

    Application.savedata_game.system.embodied = false
  end

#ifdef :ITEFU_DEVELOP
  def setup_debug_input
    input = Application.input
    semantic = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32).instance_eval do
      define(DebugInput::FORCE_WIN, Itefu::Input::Win32::Code::VK_F5)
      define(DebugInput::FORCE_LOSE, Itefu::Input::Win32::Code::VK_F6)
      define(DebugInput::FORCE_ESCAPE, Itefu::Input::Win32::Code::VK_F7)
      self
    end
    input.add_semantics(:battle_debug, semantic)
  end
#endif

  def on_finalize
#ifdef :ITEFU_DEVELOP
    input = Application.input
    input.remove_semantics(:battle_debug)
#endif
    troop_id = @battle.troop.troop_id
    @battle.finalize
    Application.focus.pop
    Application.language.release_message(Filename::Language::COMMON_EVENTS)
    if @battle.lang_troop
      Application.language.release_message(Filename::Language::TROOP_TEXT_n % troop_id)
    end
    Application.language.release_message(:battle)
  end

  def on_update
    if @quitted
      fade = Application.fade
      quit if fade.faded_out? && fade.fading?.!
    else
      if @battle.running?
#ifdef :ITEFU_DEVELOP
        debug_input
#endif
        @battle.update
      elsif @battle.focus.empty?
        @quitted = true

        case result.outcome
        when Itefu::Rgss3::Definition::Event::Battle::Result::WIN,
             Itefu::Rgss3::Definition::Event::Battle::Result::ESCAPE
          Application.savedata_game.system.embodied = true
        when Itefu::Rgss3::Definition::Event::Battle::Result::LOSE
          Application.savedata_game.system.embodied = @losable
        end

        unless Application.rgss_reset?
          fade = Application.fade
          unless fade.faded_out?
            if Application.savedata_game.system.embodied
              fade.fade_color(Itefu::Color.Black, 15, 15) 
            else
              fade.fade_color(Itefu::Color.Black, 90, 30) 
            end
          end
        end
      end
    end
  end

  def on_draw
    @battle.draw
  end

#ifdef :ITEFU_DEVELOP
  def debug_input
    return unless input = Application.input
    case
    when input.triggered?(DebugInput::FORCE_WIN)
      @battle.kill_all_enemies
      @battle.quit(nil, Itefu::Rgss3::Definition::Event::Battle::Result::WIN)
    when input.triggered?(DebugInput::FORCE_LOSE)
      @battle.quit(nil, Itefu::Rgss3::Definition::Event::Battle::Result::LOSE)
    when input.triggered?(DebugInput::FORCE_ESCAPE)
      @battle.quit(nil, Itefu::Rgss3::Definition::Event::Battle::Result::ESCAPE)
    end
  end
#endif
end


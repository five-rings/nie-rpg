=begin
  設定画面
=end
class Scene::Game::Preference < Scene::Game::Base
  include Layout::View
  FADE_TIME_TO_SHUTDOWN = 45
  FADE_TIME_TO_RESET = 30
  SOUND_FADE_TIME = 100
  REGISTRY_MAP = {
    system_music: "PlayMusic",
    system_sound: "PlaySound",
    system_fullscreen: "LaunchInFullScreen",
    system_vsync: "WaitForVsync",
  }.freeze
  PAD_MEANS = [:decide, :cancel, :dash, :sneak, :option, :config, :quick_save, :quick_load, ].freeze

  def fading_time; @fading_time || super; end

  def on_initialize
    @message = Application.language.load_message(:preference)

    @scenegraph = Itefu::SceneGraph::Root.new
    @scenegraph.add_child(Itefu::SceneGraph::Sprite,
      Graphics.width, Graphics.height,
      Application.snapshot
    ).tap {|node|
      if Application.savedata_game.system.embodied
        node.sprite.opacity = 0x5f
        # node.sprite.opacity = 0xaf
        # node.sprite.color = Color.new(0xfa, 0xff, 0xac, 0xcf)
      else
        node.sprite.opacity = 0x7f
      end
    }

    @language = Itefu::Language::locale

    begin
      @system_properties = Win32::Registry.open {|reg|
        Hash[REGISTRY_MAP.map {|key, value|
          [key, reg.getValue(value) == 1]
        }]
      }
    rescue => e
      ITEFU_DEBUG_OUTPUT_WARNING "Failed to read registry in Scene::Preference"
      ITEFU_DEBUG_OUTPUT_WARNING e.inspect
    end

    # @padconf = Application.instance.pad_config
    @padconf = Application.savedata_system.input.joypad
    pad_assignments = Hash[PAD_MEANS.map {|mean|
      [mean, @padconf.entities(mean)[0]]
    }]

    volumes = Application.savedata_system.preference.volumes

    @viewmodel = ViewModel.new(Itefu::Language::locale, Language::Locale.labels, @system_properties, pad_assignments, volumes)
    load_layout("menu/preference", @viewmodel)
    control(:menu).tap do |control|
      control.add_callback(:decided, method(:on_menu_decided))
    end
    control(:languages).tap do |control|
      control.add_callback(:decided, method(:on_lang_decided))
    end
    control(:pad_list).tap do |control|
      control.add_callback(:decided, method(:on_pad_decided))
    end
    control(:pad_window).tap do |control|
      control.custom_operation = method(:operation_pad)
      control.add_callback(:update, method(:on_pad_update))
    end
    control(:volume_list).tap do |control|
      control.add_callback(:decided, method(:on_volume_decided))
    end
    control(:volume_dial).tap do |control|
      control.add_callback(:decided, method(:on_dial_decided))
      control.add_callback(:canceled, method(:on_dial_canceled))
      control.add_callback(:value_changed, method(:on_dial_changed))
      def control.on_value_changing_effect(i,n,o); end
    end

    @pad_status = Itefu::Input::Status::Win32::JoyPad.new(0)
    @pad_targets = Itefu::Input::Win32::JoyPad::Code.constants.map {|key|
        Itefu::Input::Win32::JoyPad::Code.const_get(key)
      }.select {|code|
        code >= Itefu::Input::Win32::JoyPad::Code::BUTTON_BASE
      }
    @pad_targets.uniq!
    @pad_status.setup(@pad_targets)

    if ver = Application.config.version
      @viewmodel.version = ver
    end


    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end

  def exit(*args)
    clear_focus
    super
  end

  def on_finalize
    finalize_layout
    @scenegraph.finalize
    if @message
      Application.language.release_message(:preference)
      @message = nil
    end
  end

  def update_state
    super
    @scenegraph.update
    @scenegraph.update_interaction
    @scenegraph.update_actualization
  end

  def on_update
    @pad_status.update
    if control(:volume_dial).focused?
      case @viewmodel.volume_target.value
      when :bgm
        unless Itefu::Sound.playing_bgm?
          @bgm_played = true
          Itefu::Sound.play_bgm("Town4", 70, 85)
        end
      when :bgs
        unless Itefu::Sound.playing_bgs?
          @bgs_played = true
          Itefu::Sound.play_bgs("Wind", 70, 60)
        end
      when :me
        @me_played = true
        Itefu::Sound.play_me("Victory1", 100, 95)
      end
    end
    update_layout
  end

  def on_draw
    @scenegraph.draw
    draw_layout
  end

  def on_enter_main
    push_focus(:menu)
  end

  def on_update_main
    if focus.empty?
      # レジストリの反映
      if @system_properties && REGISTRY_MAP.find_index {|key, value|
          @system_properties[key] != @viewmodel.system_properties[key].value
      }
        begin
          Win32::Registry.new {|reg|
            REGISTRY_MAP.each do |key, value|
              current_value = @viewmodel.system_properties[key].value
              next unless @system_properties[key] != current_value
              reg.setValue(value, current_value ? 1 : 0)
            end
          }
        rescue => e
          ITEFU_DEBUG_OUTPUT_WARNING "Failed to write to registry in Scene::Preference"
          ITEFU_DEBUG_OUTPUT_WARNING e.inspect
          raise
        end
      end

      # 言語設定の反映
      if @language != Itefu::Language::locale
        Application.savedata_system.preference.locale = Itefu::Language::locale
        unless Application.instance.save_savedata
          # 非実体時などはセーブできないのでセーブデータを読み直さない状態で再起動する
          Application.instance.no_load = true
        end
        Application.instance.map_notices << :lang_info
        @fading_time ||= FADE_TIME_TO_RESET
        # リセットが必要
        exit @exit_code || :reset
      else
        exit @exit_code
      end
    end
  end

  # 設定項目の選択
  def on_menu_decided(control, index, x, y)
    if c = control.child_at(index)
      case c.name
      when :lang
        # 言語設定
        c2 = self.control(:languages)
        c2.cursor_index = Language::Locale.availables.find_index {|l| l == Itefu::Language::locale } || 0
        push_focus(c2)
      when :quit
        # 設定完了
        pop_focus
      when :shutdown
        # ゲーム終了
        @exit_code = :shutdown
        @fading_time = FADE_TIME_TO_SHUTDOWN
        pop_focus
      when :system_music,
           :system_sound,
           :system_fullscreen,
           :system_vsync
        # システム設定
        @viewmodel.system_properties[c.name].value = @viewmodel.system_properties[c.name].value.!
      when :assignments
        push_focus(:pad_list)
      when :volumes
        push_focus(:volume_list)
      end
    end
  end

  # 使用言語を決定
  def on_lang_decided(control, index, x, y)
    lang = Language::Locale.availables[index]
    if Language::Locale.available?(lang)
      Itefu::Language::locale = lang
      @viewmodel.current_language = lang
    end
    pop_focus
  end

  # 設定するパッドを選択
  def on_pad_decided(control, index, x, y)
    return unless c = control.child_at(index)
    @assign_target = c.name
    push_focus(:pad_window)
  end

  # 割り当てるパッドの入力
  def on_pad_update(control)
    return unless control.focused?
    return if control.window.openness < 0xff
    return unless v = @pad_targets.find {|code|
      @pad_status.triggered?(code)
    }
    assign_to_pad(v)
    pop_focus
  end

  def operation_pad(control, code, *args)
    return if @pad_targets.any? {|pad|
      @pad_status.pressed?(pad)
    }

    if code == Operation::DECIDE
      assign_to_pad(nil)
    end
    code
  end

  def assign_to_pad(code)
    @padconf.entities(@assign_target).clear
    @padconf.define(@assign_target, code)
    Application.input.reset_key_mapping
    Application.input.update # trigger判定が再送されてしまうので一度空で呼んで捨てる
    @viewmodel.pad_assignments[@assign_target].value = code
  end

  # 音量を変更する対象を選択
  def on_volume_decided(control, index, x, y)
    return unless c = control.child_at(index)
    case c.name
    when :bgm, :me
      unless @viewmodel.system_properties[:system_music].value
        notice = @message.text(:notice_volume_music)
      end
    when :bgs, :se
      unless @viewmodel.system_properties[:system_sound].value
        notice = @message.text(:notice_volume_sound)
      end
    end
    if notice
      @viewmodel.notice = notice
      push_focus(:notice_window)
    else
      @viewmodel.volume_target = c.name
      @volume_before_change = Application.savedata_system.preference.volumes[c.name]
      self.play_animation(:volume_window, :in)
      c2 = push_focus(:volume_dial)
      volumes = @viewmodel.volumes
      c2.cursor_index = 1
      c2.number = c2.binding(0) { volumes[c.name] }

      if c.name == :me
        @bgm_cache = Itefu::Sound.actual_bgm
        Itefu::Sound.stop_bgm(SOUND_FADE_TIME)
      end
    end
  end

  def on_dial_decided(control, index, x, y)
    close_volume_dial
    pop_focus
  end

  def on_dial_canceled(control, index)
    # キャンセル時はボリュームを元に戻す
    target = @viewmodel.volume_target.value
    Application.savedata_system.preference.volumes[target] = @volume_before_change
    @viewmodel.volumes[target].modify @volume_before_change
    Audio.apply_volumes(Application.savedata_system.preference.volumes)

    # 
    close_volume_dial
  end

  def on_dial_changed(control, index, num, newnum)
    if (num - newnum).abs >= 100
      change_volume
    else
      change_volume(0)
    end
    if num != newnum
      Sound.play_select_se
    end
  end

  def close_volume_dial
    if @bgm_played
      Itefu::Sound.stop_bgm(SOUND_FADE_TIME)
      @bgm_played = false
    end
    if @bgs_played
      Itefu::Sound.stop_bgs(SOUND_FADE_TIME)
      @bgs_played = false
    end
    if @me_played
      Itefu::Sound.stop_me(SOUND_FADE_TIME)
      @me_played = false
    end
    if @bgm_cache
      Itefu::Sound.play(@bgm_cache, 0)
      @bgm_cache = nil
    end
    self.play_animation(:volume_window, :out)
  end

  def change_volume(fade = SOUND_FADE_TIME)
    target = @viewmodel.volume_target.value
    Application.savedata_system.preference.volumes[target] = @viewmodel.volumes[target].value
    Audio.apply_volumes(Application.savedata_system.preference.volumes)
    case target
    when :bgm
      Itefu::Sound.play(Itefu::Sound.current_bgm, fade)
    when :bgs
      Itefu::Sound.play(Itefu::Sound.current_bgs, fade)
    end
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :languages, :current_language
    attr_accessor :system_properties
    attr_accessor :pad_assignments
    attr_accessor :volumes
    attr_observable :volume_target
    attr_observable :notice
    attr_observable :version

    LangData = Struct.new(:id, :label)

    def initialize(lang, langs, sysprops, pads, volumes)
      self.languages = langs.map {|id, label|
        LangData.new(id, label)
      }
      self.current_language = lang
      self.system_properties = sysprops && Hash[
        sysprops.map {|key, value|
          [key, Itefu::Layout::ObservableObject.new(value)]
        }
      ] || Hash[
        REGISTRY_MAP.each_key.map {|key|
          [key, nil]
        }
      ]
      self.pad_assignments = Hash[
        pads.map {|key, value|
          [key, Itefu::Layout::ObservableObject.new(value)]
        }
      ]
      self.volumes = Hash[
        volumes.map {|key, value|
          [key, Itefu::Layout::ObservableObject.new(value)]
        }
      ]
      self.notice = ""
      self.volume_target = nil
      self.version = Itefu::Build.target
    end

  end

end

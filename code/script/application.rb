=begin
  タイトル独自のアプリケーション実装
=end
class Application < Itefu::Application
  include Itefu::Resource::Loader
  include Itefu::Resource::Container
  attr_reader :language
  attr_reader :config
  # attr_reader :pad_config
  attr_reader :focus
  attr_reader :savedata_system, :savedata_game
  attr_reader :map_notices
  attr_reader :font_system_default
  attr_accessor :no_load # セーブデータを読み直さずに再起動する
  
  INI = Filename::Ini

  Registry = Struct.new(:LaunchInFullScreen, :PlayMusic, :PlaySound, :WaitForVsync)

  def self.instance; $itefu_application; end
  def self.running?; instance.running?; end

  def self.input; instance.system(Input::Manager.klass_id); end
  def self.scene; instance.system(Itefu::Scene::Manager); end
  def self.timer; instance.system(Itefu::Timer::Manager); end
  def self.fade;  instance.system(Itefu::Fade::Manager);  end
  def self.sound; instance.system(Itefu::Sound::Manager); end
  def self.animation; instance.system(Animation::Manager); end
#ifdef :ITEFU_DEVELOP
  def self.performance; instance.system(Itefu::Debug::Performance::Manager); end
#endif

  def self.database; Itefu::Database.instance; end
  def self.language; instance.language; end
  def self.config; instance.config; end
  def self.focus; instance.focus; end
  def self.savedata_system; instance.savedata_system; end
  def self.savedata_game; instance.savedata_game; end

  # セーブデータを切り替える
  def self.load_game
    instance.instance_eval {
      # セーブデータの読み込みにDBを参照するのでデータ読み込み前にリセットしている
      # セーブデータの読み込みに失敗した場合はDBだけリセットされてしまうがタイトルかデバッグメニューだけで読み込むうちは問題ない
      load_database
      if data = yield
        @savedata_game = data
      end
    }
  end
  
  # 終了時に自動解放するリソースを生成する
  def self.resident_resource(id, klass, *args, &block)
    instance.resident_resource(id, klass, *args, &block)
  end
  
  def resident_resource(id, klass, *args, &block)
    @resident_resources[id] ||= create_resource(klass, *args, &block)
  end
  
  def clear_resident_resources
    @resident_resources.clear
    finalize_all_resources
  end
  
  def save_savedata(index = nil)
    SaveData.save_system(@savedata_system)
    if index
      SaveData.save_game(index, @savedata_game)
    else
      SaveData.save_game_temp(@savedata_game)
    end
  end
  
  WM_CLOSE = 0x10

private
  def on_initialize
#ifdef :ITEFU_DEVELOP
    @start_time = Itefu::Timer::Win32.timeGetTime
#endif
    @resident_resources = {}
    @graphics_counter = 0
    @graphics_update_rate = 1
    @map_notices = []
    @font_system_default = Font.default_name
    load_registry
    hook_close
    enable_aspect
    load_config
    restore_main_window
    setup_savedata
  end
  
  def impl_reset
    super
    clear_resident_resources
  end

#ifndef :ITEFU_DEVELOP
  def impl_running
    super
  rescue RGSSReset
    raise
  rescue Exception
    # save crashing data
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    Itefu::SaveData::Loader.save(Filename::SaveData::SYSTEM_CRASHED_s % timestamp, @savedata_system)
    Itefu::SaveData::Loader.save(Filename::SaveData::GAME_CRASHED_s % timestamp, @savedata_game)
    raise
  end
#endif

  def on_pre_running
    release_all_resources
    # load_padconf
    load_config_reloadable
    load_systemdata
    load_language
    load_database
    load_gamedata
    setup_systems
    setup_window
    setup_focus
    load_system_resources
#ifdef :ITEFU_DEVELOP
    unless Application.debug_draw?
      Application.disable_debug_draw
    end
    end_time = Itefu::Timer::Win32.timeGetTime
    ITEFU_DEBUG_OUTPUT_NOTICE "loading time #{end_time - @start_time}"
#endif
    @no_load = false if @no_load
  end

  def load_registry
    @registry = Registry.new(false, true, true, false)
    begin
      Win32::Registry.new {|reg|
        Registry.members.each do |m|
          if ret = reg.getValue(m.to_s)
            @registry[m] = ret == 1
          else
            reg.setValue(m.to_s, @registry[m] ? 1 : 0)
          end
        end
      }
    rescue => e
      ITEFU_DEBUG_OUTPUT_ERROR e.inspect
    end
  end

  def hook_close
    hwnd = Itefu::Win32::getWindowHandle
    Itefu::Win32::Hook.enable(hwnd)
    Itefu::Win32::Hook.hook_window_message(WM_CLOSE, true)
  end
  
  def enable_aspect
#ifdef :ITEFU_DEVELOP
    Itefu::Aspect::Profiler.enable_scene_manager
    Itefu::Aspect::Profiler.enable_layout_view
    Aspect::Profiler.enable_map
#endif
  end
  
  def load_config
    @config = Config::MyConfig.new
    @config.load(Filename::Config::GENERAL)
    @config.version = load_data(Filename::Config::VERSION) rescue nil
  end

  def load_config_reloadable
    Config::ExpTable.load
    Config::Params.load
  end

=begin
  def load_padconf
    @pad_config = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32::JoyPad, 0)

    File.open(Filename::PAD_CONFIG, "r") {|f|
      f.each_line do |l|
        key, *args = l.chomp.split(",")
        next if key.start_with?("#")
        begin
          key = key.intern
          args.map! {|a| Integer(a) }
        rescue => e
          ITEFU_DEBUG_OUTPUT_ERROR e
          next
        end
        args.each do |arg|
          @pad_config.define(key, arg)
        end
      end
    }
  rescue => e
    ITEFU_DEBUG_OUTPUT_ERROR e
  end
=end

  def load_language
    Language::Locale.check_languages_available

    # locale
    Itefu::Language.locale = config.locale ||
      @savedata_system.preference.locale ||
      Language::Locale.getLocaleFromString(Win32::Locale.getUserDefaultLocaleName) ||
      Language::Locale.getLocaleFromString(getIniString(INI, :Game, :LANG)) ||
      Language::Locale::DEFAULT
    # Font for locale
    Font.default_name = Language::Locale.default_font || self.font_system_default

    # load message data
    @language = Language.new
    language.load_message(:application)
    language.load_message(:system)
    language.load_message(:database)
    language.load_message(:game)
    language.load_message(:map_name)
    language.load_message(Filename::Language::COMMON_EVENTS)
    language.load_message(Filename::Language::MAP_TEXT_COMMON)
  end

  def setup_savedata
    Dir::mkdir(Filename::SaveData::PATH) unless File.directory? Filename::SaveData::PATH
  rescue => e
    msgbox(language.message(:application, :savedata), "\n", e.message) 
  end

  def load_database
    if @no_load
      # 言語設定のみ読み替える
      Itefu::Database.instance.db_tables.each do |id, db|
        db.replace_text
      end
    else
      Itefu::Database.create(Itefu::Database::Loader)
      Itefu::Database.load_rgss3_tables
      Database.precomputing
    end
  end

  def load_systemdata
    unless @no_load
      @savedata_system ||= SaveData.load_system_or_new # not to reload when resetting
    end
    Audio.apply_volumes(@savedata_system.preference.volumes)
  end

  def load_gamedata
    return if @no_load
    @savedata_game = SaveData.load_game_temp_or_new
  end

  def setup_systems
    add_system(Itefu::Timer::Manager)
#ifdef :ITEFU_DEVELOP
    add_system(Itefu::Debug::Performance::Manager, Viewport::Debug::PERFORMANCE)
#endif
    Itefu::Rgss3::Viewport.new.auto_release {|vp|
      vp.z = Viewport::Display::FADE
      add_system(Itefu::Fade::Manager, vp)
    }
    hwnd = Itefu::Win32::getWindowHandle
    add_system(Input::Manager).
      add_semantics(:win32, @savedata_system.input.win32).
      add_semantics(:joypad, @savedata_system.input.joypad).
      # add_semantics(:joypad, @pad_config).
#ifdef :ITEFU_DEVELOP
      add_semantics(:app_debug, Itefu::Input::Semantics.new(Itefu::Input::Status::Win32).instance_eval {
        define(Input::Debug::TOGGLE_DRAW, Itefu::Input::Win32::Code::VK_PAUSE)
        define(Input::Debug::SAVE_CAPTURE, Itefu::Input::Win32::Code::VK_SNAPSHOT)
        define(1, Itefu::Input::Win32::Code::VK_1)
        define(2, Itefu::Input::Win32::Code::VK_2)
        define(3, Itefu::Input::Win32::Code::VK_3)
        define(4, Itefu::Input::Win32::Code::VK_4)
        self
      }).
#endif
      extend(Itefu::Input::Dll).
      set_window_handle(hwnd).
      add_keys_to_suppress(
        Itefu::Input::Win32::Code::VK_F1,
        Itefu::Input::Win32::Code::VK_F12,
      )
    add_system(Itefu::Scene::Manager, Scene::Root)
    add_system(Animation::Manager)
    add_system(Itefu::Sound::Manager)
  end

  def setup_window
    Itefu::Rgss3::Window.default_skin = resource_data(load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::WINDOWSKIN))
    # 頻繁に使用するサイズのウィンドウを事前生成する
    # Itefu::Rgss3::Resource::Pool.create(1, Itefu::Rgss3::Window, 0, 0, 640, 480)
  end
  
  def setup_focus
    @focus = Itefu::Focus::Controller.new
    focus.activate
  end
  
  # 常時読み込んだ状態にしておくリソース
  def load_system_resources
    load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::ICONSET)
    load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BALLOON)
    load_rvdata2_resource(Itefu::Rgss3::Filename::Data::TILESETS)
    load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::CHARACTERS_s % "")
    load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::FACES_s % "")
  end

  # 全てのシーンから抜けたら終了する
  def running?; system(Itefu::Scene::Manager).running?; end

  def on_running
    input = system(Itefu::Input::Manager)
#ifdef :ITEFU_DEVELOP
    case
    when input.triggered?(Input::Debug::TOGGLE_DRAW)
      # toggle debug draw
      Application.toggle_debug_draw
    when input.triggered?(Input::Debug::SAVE_CAPTURE)
      # save capture
      if bitmap = Application.suspend_debug_draw {
            Application.create_snapshot
          }
        file = Filename::SaveData::CAPTURED_s % Time.now.strftime("%Y%m%d-%H%M%S")
        begin
          bitmap.export(file)
        rescue => e
          ITEFU_DEBUG_OUTPUT_ERROR e
        end
      end
    end

    case
    when input.triggered?(1)
      @graphics_update_rate = 1
    when input.triggered?(2)
      @graphics_update_rate = 2
    when input.triggered?(3)
      @graphics_update_rate = 3
    when input.triggered?(4)
      @graphics_update_rate = 4
    end
#endif
    if input.key_suppressed?(Itefu::Input::Win32::Code::VK_F12)
      fade = system(Itefu::Fade::Manager)
      fade.fade_out(5, 0) unless fade.faded_out?
      raise RGSSReset
    end
    if Itefu::Win32::Hook.window_message_sent?(WM_CLOSE)
      system(Itefu::Scene::Manager).quit
    end
  end

#ifdef :ITEFU_DEVELOP
  def rgss3_graphics_update
    if @graphics_counter == 0
      super
    end
    @graphics_counter += 1
    @graphics_counter = 0 if @graphics_counter >= @graphics_update_rate
  end
#endif

  def on_aborted(exception)
    if input = Application.input
      input.clear_keys_to_suppress
    end
  end
  
  def error_message(logfile)
    if language && (text = language.message(:application, :exception))
      "#{language.message(:application, :exception)}#{logfile}"
    else
      <<"EOM"
Aborted because this application can't keep it running for some reason.

Information for Developers: #{logfile}
EOM
    end
  end

  def on_logging(io)
    if @savedata_system
      io.puts "SaveData: version.#{@savedata_system.version}"
    else
      io.puts "SaveData: nil"
    end
    if @config && @config.version
      io.puts "Build: #{@config.version}"
    else
      io.puts "Build: nil"
    end
  end

  def on_finalized
    save_window_position
    Itefu::Rgss3::Window.default_skin = nil
    finalize_all_resources
    release_all_resources
    release_language
    save_savedata
    Itefu::Database.unload_all_tables
#ifdef :ITEFU_DEVELOP
    Itefu::Rgss3::Resource.resource_classes.each {|klass| klass.dump_log($stderr) }
#endif
  end

  def release_language
    language.release_all_messages
    @language = nil
  end
  
  def restore_main_window
    if @registry.LaunchInFullScreen
      # フルスクリーンモード
      # 画面サイズの変更
      Graphics.resize_screen(config.screen_width, config.screen_height)
    else
      hwnd = Itefu::Win32::getWindowHandle
      # ウィンドウモード
      # ウィンドウのサイズや位置変更を非表示状態で行う
      Itefu::Win32::hideWindow(hwnd)
      # 画面サイズの変更
      Graphics.resize_screen(config.screen_width, config.screen_height)
      # ウィンドウ位置のリストア
      if getIni(INI, :Window, :RESTORE, 1) != 0
        x = getIni(INI, :Window, :POS_X)
        y = getIni(INI, :Window, :POS_Y)
        Itefu::Win32::setWindowPos(hwnd, x, y) if x && y
      end
      # ウィンドウを表示状態に戻す
      # 外部からウィンドウ非表示で起動すれば、リストアが終わるまでウィンドウを非表示にできる
      Itefu::Win32::showWindow(hwnd)
      # 前にアクティブだったウィンドウが前面にくることがあるので無理矢理Zオーダーを上げる
      Itefu::Win32::bringWindowToTop(hwnd)
      Itefu::Win32::setTopWindowForcibly(hwnd)
      Itefu::Win32::setActiveWindow(hwnd)
      Itefu::Win32::setForegroundWindow(hwnd)
    end
  end
  
  def save_window_position
    # フルスクリーン時は0,0になるので保存しない
    hwnd = Itefu::Win32::getWindowHandle
    return if Itefu::Win32::fullScreenMode?(hwnd)

    if getIni(INI, :Window, :RESTORE, 1) != 0
      x, y = Itefu::Win32::getWindowPos(Itefu::Win32::getWindowHandle)
      writeIni(INI, :Window, :POS_X, x)
      writeIni(INI, :Window, :POS_Y, y)
    end
  end
  
  def getIni(m, section, key, *args)
    Itefu::Win32::getPrivateProfileInt(m::FILENAME, section.to_s, m.const_get(section).const_get(key), *args)
  end

  def getIniString(m, section, key, *args)
    Itefu::Win32::getPrivateProfileString(m::FILENAME, section.to_s, m.const_get(section).const_get(key), *args)
  end
  
  def writeIni(m, section, key, *args)
    Itefu::Win32::writePrivateProfileInt(m::FILENAME, section.to_s, m.const_get(section).const_get(key), *args)
  end

#ifdef :ITEFU_DEVELOP
  # デバッグ表示をしているか
  def self.debug_draw?
    @disable_debug_draw.!
  end
  
  # デバッグ表示の切り替え
  def self.toggle_debug_draw
    if @disable_debug_draw
      enable_debug_draw
    else
      disable_debug_draw
    end
  end
  
  # 一時的にデバッグ表示を消し任意の処理を実行後元に戻す
  def self.suspend_debug_draw
    if debug_draw?
      disabling = true
      disable_debug_draw
    end
    ret = yield
    if disabling
      enable_debug_draw
    end
    ret
  end

  # デバッグ表示を有効にする
  def self.enable_debug_draw
    @disable_debug_draw = false
    performance.activate
    Itefu::Layout::Control::RenderTarget.debug_draw_boundary = true
  end

  # デバッグ表示を無効にする
  def self.disable_debug_draw
    @disable_debug_draw = true
    performance.deactivate
    Itefu::Layout::Control::RenderTarget.debug_draw_boundary = false
  end
#endif

end


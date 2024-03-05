=begin
  ファイル名など
=end
module Filename

#ifdef :ITEFU_DEVELOP
  PAD_CONFIG = "padconf_dev.csv"
#else
  PAD_CONFIG = "padconf.csv"
#endif

  module Ini
    FILENAME = File.basename(Itefu::Win32.getModuleFileName, ".exe") + ".ini"

    module Game
      LANG = "lang"
    end

    module Window
      RESTORE = "restore"
      POS_X = "pos_x"
      POS_Y = "pos_y"
    end
  end

  module Config
    PATH = "Data/Config"
    GENERAL = "#{PATH}/config.rb"
    EXPTABLE = "#{PATH}/exptable.rb"
    PARAMS = "#{PATH}/params.rb"
    VERSION = "#{PATH}/version.dat"
  end
  
  module Language
    PATH = "Data/Language"
    MAP_TEXT_n = "text/Map%03d"
    MAP_TEXT_COMMON = "text/MapCommon"
    COMMON_EVENTS = :"text/CommonEvents"
    TROOP_TEXT_n = "text/Troop%03d"
  end

  module SaveData
    PATH = "SaveData"
    SYSTEM = "#{PATH}/system.dat"
    SYSTEM_CRASHED_s = "#{PATH}/crash_system_%s.dat"
    GAME_TEMP = "#{PATH}/savedata_tmp.dat"
    GAME_DUPLICATED_s = "#{PATH}/savedata_%s.dat"
    GAME_DUPLICATED_REG = /(?<!crash_)savedata_([0-9]+)([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})\.dat$/
    GAME_CRASHED_s = "#{PATH}/crash_savedata_%s.dat"
    GAME_n = "#{PATH}/savedata%03d.dat"
    BACKUP = "#{PATH}/backup.dat"
    SNAPSHOT_n = "#{PATH}/snapshot%03d.bmp"
    SNAPSHOT_TEMP = "#{PATH}/snapshot.tmp"
#ifdef :ITEFU_DEVELOP
    CAPTURED_s = "#{PATH}/capture%s.bmp"
#endif
  end
  
  module Layout
    PATH = "Data/Layout"
  end

  module BehaviorTree
    DATA_s = "Data/Behavior/%s.rb.dat"
  end

  module Graphics
    module Gimmick
      PATH = "Graphics/Gimmick"
    end
    module Ui
      PATH = "Graphics/UI"
      PATH_MAP = PATH + "/Map"
      PATH_MENU = PATH + "/FieldMenu"
    end
  end

#ifdef :ITEFU_DEVELOP
  module Tool
    PATH = "../tool"
    BAT = "#{PATH}/bat"
    CONVERT_RESOURCES = "#{BAT}/convert_resources.bat"
    CONVERT_LAYOUT = "#{BAT}/convert_layout.bat" 
    CONVERT_TEXT = "#{BAT}/convert_text.bat" 
  end
#endif

end

=begin
  セーブデータ関連  
=end
module SaveData

  # ゲーム全体に関するデータを読み込む
  def self.load_system
    Itefu::SaveData::Loader.load(Filename::SaveData::SYSTEM, SaveData::System)
  end
  
  # ゲーム全体に関するデータを読み込むか、なければ新規に作成する
  def self.load_system_or_new
    load_system || Itefu::SaveData::Loader.new_data(SaveData::System)
  end
  
  # 一時保存された場所から再開する
  def self.load_game_temp
    Itefu::SaveData::Loader.load(Filename::SaveData::GAME_TEMP, SaveData::Game)
  end
  
  # 一時保存された場所があればそこから、なければ新規にゲームを開始する
  def self.load_game_temp_or_new
    load_game_temp || new_game
  end
  
  # 保存された場所から再開する
  def self.load_game(index)
    Itefu::SaveData::Loader.load(Filename::SaveData::GAME_n % index, SaveData::Game).tap {|data|
      if data
        data.system.save_slot = index
      end
    }
  end
  
  # 保存されたデータのプレビューに必要な部分だけを読み込む
  def self.load_preview(file)
    Itefu::SaveData::Loader.load(file, SaveData::Game::Preview)
  end

  # 任意のデータを読み込む
  def self.load_game_file(file)
    Itefu::SaveData::Loader.load(file, SaveData::Game)
  end
  
#ifdef :ITEFU_DEVELOP
  # 任意のデータを読み込む
  def self.debug_load_game(file)
    load_game_file(file)
  end
#endif
  
  # 新しくゲームを始める
  # @note タイトル画面用のマップから開始する
  def self.new_game
    save_game = Itefu::SaveData::Loader.new_data(SaveData::Game)
    save_game.map.reset_to_start_position
    save_game
  end
  
  # 新しいデータでゲームを始める
  # @note エディタで設定された初期位置から開始する
  def self.new_data
    Itefu::SaveData::Loader.new_data(SaveData::Game)
  end
  
  # システムデータを保存する
  def self.save_system(data)
    Itefu::SaveData::Loader.save(Filename::SaveData::SYSTEM, data)
  end
  
  # 一時保存データを作成する
  def self.save_game_temp(data)
    # タイトル画面以外でのみ中断セーブする
    if data.system.embodied && data.system.to_save
      # 上書き対象をbackup
      backup_game_file(Filename::SaveData::GAME_TEMP)
      # 保存
      Itefu::SaveData::Loader.save(Filename::SaveData::GAME_TEMP, data)
    end
  end

  # 一時保存データを削除する
  def self.clear_save_game_temp
    backup_game_file(Filename::SaveData::GAME_TEMP)
  end

  # セーブデータを保存する
  def self.save_game(index, data)
    # 上書き対象をbackup
    file = Filename::SaveData::GAME_n % index
    backup_game_file(file)
    # 保存
    data.system.save_slot = index
    Itefu::SaveData::Loader.save(file, data)
  end

  # 指定したゲームデータが存在するか
  def self.game_data_exists?(index = nil)
    if index
      File.file?(Filename::SaveData::GAME_n % index)
    else
      File.file?(Filename::SaveData::GAME_TEMP)
    end
  end
  
#ifdef :ITEFU_DEVELOP
  # 任意のデータを作成する
  def self.debug_save_game(file, data)
    Itefu::SaveData::Loader.save(file, data)
  end
#endif

  # 指定したファイルをbackup用ファイルに移動する
  def self.backup_game_file(file)
    File.delete(Filename::SaveData::BACKUP) if File.file?(Filename::SaveData::BACKUP)
    File.rename(file, Filename::SaveData::BACKUP) if File.file?(file)
  end
  
  # 指定した番号のセーブデータをbackup用ファイルに移動する
  def self.backup_game(index)
    backup_game_file(Filename::SaveData::GAME_n % index)
  end
  
  # 指定したファイルをbackup用ファイルで置き換える
  def self.restore_game_file_from_backup(file)
    File.delete(file) if File.file?(file)
    File.rename(Filename::SaveData::BACKUP, file) if File.file?(Filename::SaveData::BACKUP)
  end
  
  # 指定した番号のセーブデータをbackupファイルで置き換える
  def self.restore_game_from_backup(index)
    restore_game_file_from_backup(Filename::SaveData::GAME_n % index)
  end

  # 指定した内容をbackup用ファイルに書き込む
  def self.backup_game_data(data)
    Itefu::SaveData::Loader.save(Filename::SaveData::BACKUP, data)
  end

  # ゲームデータをコピーする
  def self.copy_game_data(file, index = nil)
    if File.file?(file)
      ITEFU_DEBUG_OUTPUT_ERROR "can't copy gamedata #{index} because #{file} already exists"
    else
      game_file = index && Filename::SaveData::GAME_n % index || Filename::SaveData::GAME_TEMP
      File.open(game_file, "rb") {|fi|
        File.open(file, "wb") {|fo|
          fo.write fi.read
        }
      }
    end
  end

  # ゲームデータを複製する
  # @note 複製するファイルはタイムスタンプをつけて個別化する
  def self.duplicate_game_data(index = nil)
    file = Filename::SaveData::GAME_DUPLICATED_s % Time.now.strftime("%Y%m%d-%H%M%S")
    copy_game_data(file, index)
  end

end

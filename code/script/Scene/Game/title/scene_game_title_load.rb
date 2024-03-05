=begin
　　タイトル画面のゲームロード
=end
class Scene::Game::Title::Load < Scene::Game::Base
  include Scene::Game::SaveLoad

  def fading_time
    Application.savedata_game.system.embodied ? 60 : super
  end

  def on_initialize(mode = nil, message = nil)
    initialize_saveload(START_INDEX)
    case mode
    when :new_game
      # NewGame + バックアップ
      unless Application::Accessor::SystemData.offering.items.empty?
        @has_benefit = true
        @newgame = true
      end
      collect_backups
    else
      # 通常
      collect_entries
      # NewGame時に持ち越しなしにする
      @to_clear_benefit = true
      @newgame = true
    end
    shift_page(0)
    load_layout("menu/save", @viewmodel)
    # セーブデータ一覧
    control(:records).tap do |control|
      if @newgame
        control.cursor_index = 0
        # デフォルトカーソルの位置の詳細を表示しておく
        if @preview_to_apply = create_preview_to_new_game
          @count_to_apply_detail = 0
        end
      else
        if @entries.size > 1
          control.cursor_index = 1
        else
          control.cursor_index = 0
        end
        # デフォルトカーソルの位置の詳細を表示しておく
        reserve_preview(control.cursor_index, 0)
      end
      control.custom_operation = method(:custom_operation)
      control.custom_scroll = method(:custom_scroll)
      control.add_callback(:decided, method(:on_decided))
      control.add_callback(:cursor_changed, method(:cursor_changed))
      control.cursor_decidable = method(:cursor_decidable)
      control.add_callback(:constructed_children) {|_, items|
        setup_next_page
        change_cursor_to_next_page(control, items)
      }
    end
    # 進む戻るボタン
    setup_next_page
    # 
    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end
  
  def on_finalize
    Application.focus.pop
    finalize_layout
    finalize_saveload
  end
  
  def on_update
    @fiber_detail.resume
    update_layout
  end
  
  def on_draw
    draw_layout
  end

  def on_enter_main
    push_focus(:records)
  end
  
  def on_update_main
    if focus.empty?
      exit
    end
  end
  
private

  def cursor_decidable(control, index)
    if @newgame
      (@start_index + index) == 0 || @entries[@start_index + index]
    else
      @entries[@start_index + index]
    end
  end

  # セーブデータ一覧で決定処理
  def on_decided(control, index, x, y)
    case control.items[index]
    when :next_page
    when :new_game
      if @newgame
        # 新規データで開始
        ITEFU_DEBUG_OUTPUT_NOTICE "new game"
        Application::Accessor::SystemData.offering.items.clear if @to_clear_benefit
        Application.load_game { SaveData.new_game }
        Application.savedata_game.system.embodied = true
      else
        return
      end
      pop_focus
    else
      entry_index = @start_index + index
      # 既存データのロード
      if file = cursor_decidable(control, index)
        Application::Accessor::SystemData.offering.items.clear
        if Filename::SaveData::GAME_DUPLICATED_REG === file
          ITEFU_DEBUG_OUTPUT_NOTICE "load game #{file}"
          Application.load_game { SaveData.load_game_file(file) }
        else
          ITEFU_DEBUG_OUTPUT_NOTICE "load game #{entry_index}"
          Application.load_game { SaveData.load_game(entry_index) }
        end
      else
        return
      end
      pop_focus
    end
  end
  
  # ページの表示物に特殊なものを混ぜる
  def page_entries(num_entries, start_index)
    base = super
    if start_index == 0
      base[0] ||= :new_game if @newgame
    end
    
    # ページ切り替え
    if @last_index + 1 >= NUM_PAGE_ENTRIES
      base.push(:next_page)
    end

    base
  end

  def reserve_preview(index, *args)
    if index + @start_index == 0 && @newgame
      @preview_to_apply = create_preview_to_new_game
      @count_to_apply_detail = COUNT_TO_APPLY_DETAIL
    else
      super
    end
  end

  def create_preview_to_new_game
    SaveData::Game::Header::Summary.new(" ?", "??", "??", "?", "Actor3", 2)
  end

  def apply_detail(preview)
    case preview
    when SaveData::Game::Header::Summary
      @viewmodel.actors.modify [preview]
      @viewmodel.image = :new_game
      @viewmodel.map_name = @has_benefit ? :new_game_benefit : :new_game
    else
      super
    end
  end


  def collect_backups
    @entries = [nil]
    # 新しい日時順にリストアップする
    Dir.foreach(Filename::SaveData::PATH).reverse_each do |entry|
      next unless Filename::SaveData::GAME_DUPLICATED_REG === entry
      @entries << "#{Filename::SaveData::PATH}/#{entry}"
      # 個数制限を通常と合わせる
      break unless @entries.size < NUM_ENTRIES
    end if File.directory?(Filename::SaveData::PATH)
    @last_index = @entries.rindex {|entry| entry.nil?.! } || 0
  rescue
    @entries = [nil]
    @last_index = 0
  end

  def record_slot(start_index, i)
    file = @entries[start_index + i]
    if file && Filename::SaveData::GAME_DUPLICATED_REG === file
      :backup
    else
      super
    end
  end

  def record_label(file, header)
    if Filename::SaveData::GAME_DUPLICATED_REG === file
      Time.mktime($1, $2, $3, $4, $5, $6)
    else
      super
    end
  end

end

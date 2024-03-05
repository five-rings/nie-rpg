=begin
  フィールドメニューのセーブ画面
=end
class Scene::Game::Menu::Save < Scene::Game::Base
  include Scene::Game::SaveLoad
  CHOICE_ACCEPT_TO_SAVE = 1
  CHOICE_CANCEL_TO_SAVE = 2
  FADE_TIME_TO_RESET = 1000
  
  def on_initialize(message)
    initialize_saveload(START_INDEX)
    @viewmodel.dialog.message = message.text(:wrote_newrecord)
    @viewmodel.dialog.choices = [
      message.text(:accept_newrecord),
      message.text(:deny_newrecord),
    ]
    @viewmodel.notice = message.text(:save_slot01)
    collect_entries
    entry_index = default_entry_index
    shift_page(entry_index / NUM_PAGE_ENTRIES * NUM_PAGE_ENTRIES)
    load_layout("menu/save", @viewmodel)
    # セーブデータ一覧
    control(:records).tap do |control|
      control.custom_operation = method(:custom_operation)
      control.custom_scroll = method(:custom_scroll)
      control.add_callback(:decided, method(:on_decided))
      control.add_callback(:cursor_changed, method(:cursor_changed))
      control.add_callback(:constructed_children) {|_, items|
        setup_next_page
        change_cursor_to_next_page(control, items)
      }
      control.cursor_index = entry_index % NUM_PAGE_ENTRIES
      # デフォルトカーソルの位置の詳細を表示しておく
      reserve_preview(control.cursor_index, 0)
    end
    # 確認ダイアログ
    control(:dialog_list).tap do |control|
      control.add_callback(:decided, method(:on_dialog_decided))
      control.add_callback(:canceled, method(:on_dialog_canceled))
      control.custom_operation = method(:dialog_custom_operation)
    end
    # 進む戻るボタン
    setup_next_page
    # 
    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end
  
  # 画面に入った際にカーソルが合うセーブデータ番号
  def default_entry_index
    index = Application.savedata_game.system.save_slot
    if index && index > @last_index
      # 指定されたスロットが表示最大数より大きい
      index = nil
    end
    unless index
      # スロットの指定がない場合
      if @entries.size - @last_index > 1
        # 可能なら新規作成に
        index = @last_index + 1
      else
        # 合わせるべき箇所がないので初期値に
        index = 0
      end
    end
    index
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

  # セーブデータ一覧で決定処理
  def on_decided(control, index, x, y)
    case control.items[index]
    when :next_page
    when :back_to_title
      Itefu::Sound.stop_bgm(FADE_TIME_TO_RESET)
      Itefu::Sound.stop_bgs(FADE_TIME_TO_RESET)
      Application.instance.save_savedata
      Application.savedata_game.reset_for_restart
      Application.savedata_game.flags.ending_type = Definition::Game::EndingType::DISCARD_JOURNAL
      pop_focus
    when :new_record
      write_savedata(@start_index + index)
      confirm_to_save
    else
      if @start_index + index == 1
        control.push_focus(:notice_message)
      else
        write_savedata(@start_index + index)
        confirm_to_save
      end
    end
  end

  # 確認ダイアログの操作の上書き
  def dialog_custom_operation(control, code, *args)
    case code
    when Operation::CANCEL
      control.cursor_index = CHOICE_CANCEL_TO_SAVE
    else
      code
    end
  end
  
  # 確認ダイアログで決定処理
  def on_dialog_decided(control, index, x, y)
    case index
    when CHOICE_ACCEPT_TO_SAVE
      # do nothing
    else
      cancel_to_save
    end
    rewind_focus(:records)
  end

  # 確認ダイアログでキャンセル処理
  def on_dialog_canceled(control, index)
    cancel_to_save
  end

  # セーブデータの保存
  def write_savedata(index)
    Application.instance.save_savedata(index)
    write_snapshot(index)
    update_entry index
    shift_page(0, false)
    reserve_preview(index - @start_index, 0)
  end
  
  # スクリーンショットの保存
  def write_snapshot(index)
    bitmap = Application.snapshot
    file = Filename::SaveData::SNAPSHOT_n % index
    if File.file?(file)
      # 上書き対象のファイルを避難
      File.delete(Filename::SaveData::SNAPSHOT_TEMP) if File.file?(Filename::SaveData::SNAPSHOT_TEMP)
      File.rename(file, Filename::SaveData::SNAPSHOT_TEMP)
    end
    # 画像を保存
    begin
      bitmap.export(file)
    rescue => e
      ITEFU_DEBUG_OUTPUT_ERROR e
    end
  end
  
  # セーブ確認ダイアログの表示
  def confirm_to_save
    control(:dialog_list).tap do |control|
      control.cursor_index = CHOICE_ACCEPT_TO_SAVE
    end
    control(:records).push_focus(:dialog_list)
  end
  
  # セーブデータ保存のキャンセル処理
  def cancel_to_save
    index = Application.savedata_game.system.save_slot
    SaveData.restore_game_from_backup index
    restore_snapshot(index)
    update_entry index
    shift_page(0, false)
    reserve_preview(index - @start_index, 0)
  end
  
  # スナップショットを元に戻す
  def restore_snapshot(index)
    file = Filename::SaveData::SNAPSHOT_n % index
    File.delete(file) if File.file?(file)
    File.rename(Filename::SaveData::SNAPSHOT_TEMP, file) if File.file?(Filename::SaveData::SNAPSHOT_TEMP)
  end
  
  # ページの表示物に特殊なものを混ぜる
  def page_entries(num_entries, start_index)
    base = super
    if start_index == 0
      base[0] = :back_to_title
    end
    
    # 末尾に新規作成を置く
    if @last_index < start_index + num_entries && # 最後のページ
      @entries.size - @last_index > 1 &&          # 新規枠がまだある
      num_entries < NUM_PAGE_ENTRIES              # ページ中に余白がある
      base.push(:new_record)
    end
    # ページ切り替え
    if @last_index + 1 >= NUM_PAGE_ENTRIES
      base.push(:next_page)
    end

    base
  end

end

=begin
  セーブ/ロード画面共通の機能 
=end
module Scene::Game::SaveLoad
  include Layout::View
  START_INDEX = 0
  NUM_ENTRIES = 100
  NUM_PAGE_ENTRIES = 8
  COUNT_TO_APPLY_DETAIL = 30
  
  def initialize_saveload(si = 0)
    @start_index = @last_index = si
    @viewmodel = ViewModel.new
    @preview_cache = []
    @message = Application.language.load_message(:map_name)
    @fiber_detail = Fiber.new {
      loop {
        if @count_to_apply_detail
          if (@count_to_apply_detail -= 1) <= 0
            apply_detail(@preview_to_apply)
            @count_to_apply_detail = nil
          end
        end
        Fiber.yield
      }
    }
  end

  def finalize_saveload
    Application.language.release_message(:map_name)
    @message = nil
  end
  
  # 進む戻るボタンの設定
  # @note ページ遷移する度に生成されなおすのでその度に設定しなおす必要がある
  def setup_next_page
    control(:next_page).tap do |control|
      if control
        control.add_callback(:decided, method(:on_next_page))
        control.custom_scroll = method(:custom_scroll)
        control.cursor_index_changing = method(:cursor_changing_on_next_page)
      end
    end
  end
  
  # 内部的なセーブデータの一覧を作成する
  def collect_entries
    @entries = NUM_ENTRIES.times.map {|i|
      file = Filename::SaveData::GAME_n % i
      File.file?(file) && file || nil
    }
    @last_index = @entries.rindex {|entry| entry.nil?.! } || 0
  end
  
  # 内部的なセーブデータの情報を更新する
  def update_entry(index)
    return if index > @entries.size
    file = Filename::SaveData::GAME_n % index
    @entries[index] = File.file?(file) && file || nil
    @last_index = @entries.rindex {|entry| entry.nil?.! } || 0
  end
  
  # ページ内の表示物を変更する
  def change_page(num_entries, start_index = @start_index)
    @viewmodel.start_index = start_index
    @viewmodel.records.modify page_entries(num_entries, start_index)
  end
  
  # @return [Array] ページに表示する項目
  def page_entries(num_entries, start_index)
    @preview_cache.clear
    @entries[start_index, num_entries].map!.with_index {|file, i|
      if file
        preview = @preview_cache[i] = SaveData.load_preview(file)
        preview.save_slot = record_slot(start_index, i)
        header = preview.header
        ViewModel::RecordItem.new(header.actor_level, header.playing_time, record_label(file, header))
      end
    }
  end

  def record_slot(start_index, i)
    start_index + i
  end

  def record_label(file, header)
    map_name(header)
  end

  def map_name(header)
    id = header.map_id && ("Map%03d" % header.map_id)
    id && @message.text(id.intern) || header.map_name
  end

  # 表示するページを遷移する
  # @param [Fixnum] offset 現在のページの先頭になるエントリーをどれだけずらすか
  def shift_page(offset, to_rewind = true)
    rewind_focus(:records) if to_rewind
    @cursor_to_next_page = nil
    return unless @last_index
    @start_index += offset

    num_records = @last_index + 1
    if @start_index < START_INDEX
      if num_records % NUM_PAGE_ENTRIES == 0 && num_records < @entries.size
        # 新規作成だけがはみ出す
        @start_index = num_records
      else
        @start_index = START_INDEX + (@last_index - START_INDEX) / NUM_PAGE_ENTRIES * NUM_PAGE_ENTRIES
      end
    elsif @start_index > @last_index
      if (@start_index == num_records) && @start_index < @entries.size
        # 新規作成だけがはみ出す
        # do nothing
      else
        @start_index = START_INDEX
      end
    end

    num_entries = Itefu::Utility::Math.min(NUM_PAGE_ENTRIES, @last_index - @start_index + 1)
    change_page(num_entries)
  end

  # セーブデータ一覧での操作の上書き
  def custom_operation(control, code, *args)
    case code
    when Operation::CANCEL
      pop_focus
      code
    when Operation::MOVE_LEFT
      shift_page(-NUM_PAGE_ENTRIES)
      reserve_preview(control(:records).cursor_index)
      nil
    when Operation::MOVE_RIGHT
      shift_page(NUM_PAGE_ENTRIES)
      reserve_preview(control(:records).cursor_index)
      nil
    else
      code
    end
  end

  # セーブデータ一覧や進む戻るボタンでスクロール処理
  def custom_scroll(control, value)
    if value > 0
      shift_page(NUM_PAGE_ENTRIES)
      reserve_preview(control(:records).cursor_index)
    elsif value < 0
      shift_page(-NUM_PAGE_ENTRIES)
      reserve_preview(control(:records).cursor_index)
    end
    nil
  end
  
  # セーブデータ一覧でカーソルが移動
  def cursor_changed(control, next_index, current_index)
    reserve_preview(next_index) if next_index
  end
  
  # 詳細情報を予約する
  def reserve_preview(index, count = COUNT_TO_APPLY_DETAIL)
    @preview_to_apply = @preview_cache[index]
    @count_to_apply_detail = count
  end
  
  # 進む戻るボタンが押された
  def on_next_page(control, index, x, y)
    case index
    when 0
      shift_page(-NUM_PAGE_ENTRIES)
    when 1
      shift_page(NUM_PAGE_ENTRIES)
    end
    @cursor_to_next_page = index
  end
  
  # カーソルを進む戻るボタンに合わせる
  def change_cursor_to_next_page(control_records, items)
    if @cursor_to_next_page
      index = items.rindex {|item|
        :next_page === item
      }
      if index
        control(:next_page).custom_default_child_index = method(:default_child_index)
        control_records.cursor_index = index
      end
    end
  end
  
  # ページ変更ボタンのデフォルトカーソル
  def default_child_index(control, operation)
   # 進む戻るのうち前回選んだ方をデフォルトにする
   @cursor_to_next_page 
  end
  
  # ページ変更ボタン上でカーソル移動
  def cursor_changing_on_next_page(control, next_index, current_index, *args)
    return next_index unless args.size == 1
    case args[0]
    when Operation::MOVE_LEFT
      if current_index == 0
        shift_page(-NUM_PAGE_ENTRIES)
        @cursor_to_next_page = current_index
        return nil
      end
    when Operation::MOVE_RIGHT
      if next_index == 0
        shift_page(NUM_PAGE_ENTRIES)
        @cursor_to_next_page = current_index
        return nil
      end
    end
    next_index
  end
  
  def apply_detail(preview)
    if preview
      @viewmodel.actors.modify preview.header.summaries
      @viewmodel.image = nil # 保存で更新された場合にも確実に読み直すように一度解放する
      case preview.save_slot
      when Fixnum
        @viewmodel.image = Filename::SaveData::SNAPSHOT_n % preview.save_slot
      else
        @viewmodel.image = preview.save_slot
      end
      @viewmodel.map_name = map_name(preview.header)
    else
      @viewmodel.actors.modify []
      @viewmodel.image = nil
      @viewmodel.map_name = nil
    end
  end

  # 
  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :records
    attr_observable :actors
    attr_observable :start_index
    attr_observable :image
    attr_observable :map_name
    attr_observable :notice
    RecordItem = Struct.new(:level, :playing_time, :label)
    ActorItem = Struct.new(:level, :hp, :mp, :exp, :face_name, :face_index)
    attr_reader :dialog

    def initialize
      self.start_index = 0
      self.records = []
      self.actors = []
      self.image = nil
      self.map_name = nil
      self.notice = ""
      @dialog = Layout::ViewModel::Dialog.new
    end
  end

end

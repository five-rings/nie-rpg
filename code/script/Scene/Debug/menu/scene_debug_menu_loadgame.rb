=begin
  セーブデータを読み込んでゲームを開始する
=end
class Scene::Debug::Menu::LoadGame < Itefu::TestScene::Filer
  COUNT_TO_APPLY_DETAIL = 30

  def viewmodel_klass; ViewModel; end

  # 画像表示用に拡張する
  class ViewModel < Itefu::Scene::DebugMenu::ViewModel
    attr_observable :image
    def initialize
      super
      self.image = nil
    end
  end

  def initialize(*args, &block)
    super

    # セーブデータのスナップショット表示領域を作成
    context = @viewmodel
    c = control(:menu)
    c._(Decorator) {
      attribute width: 1.0, height: 1.0,
                unselectable: true,
                horizontal_alignment: Alignment::RIGHT,
                vertical_alignment: Alignment::BOTTOM
      _(Image) {
        self.auto_release = true
        attribute image_source: binding(nil, proc {|v|
                      case v
                      when String
                        load_image(v)
                      else
                        release_image
                      end
                    }) { context.image },
                  margin: const_box(24, 0, 0, 0),
                  width: 160, height: 120
      }
    }
    c.add_callback(:cursor_changed, method(:on_cursor_changed))

    # 画像更新にディレイを持たせる
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

  def on_update
    @fiber_detail.resume
  end
  
  def caption
    "Load Game"
  end
  
  def filtered_entry?(entry)
    (/^savedata/ === entry).!
  end

  def add_system_menu(m)
    m.add_item("Back", :back)
  end
  
  def on_file_selected(data)
    load_game("#{Filename::SaveData::PATH}/#{@path}/#{data}")
    switch_scene(Scene::Game, true)
  end

  def load_game(file)
    w = Application.load_game { SaveData.debug_load_game(file) }
    ITEFU_DEBUG_OUTPUT_NOTICE "load game #{w}"
    w
  end

  # カーソルが変わった
  def on_cursor_changed(control, next_index, current_index)
    index = next_index
    child = control && control.child_at(index)
    data, _ = child.item.data if child
    case data
    when nil, :back
      reserve_preview(nil)
    else
      previewdata = data
      reserve_preview(previewdata)
    end
  end

  # 詳細情報を予約する
  def reserve_preview(file, count = COUNT_TO_APPLY_DETAIL)
    @preview_to_apply = file
    @count_to_apply_detail = count
  end

  # 詳細情報を更新する
  def apply_detail(preview)
    if /savedata([0-9]+)/ === preview
      @viewmodel.image = nil # 保存で更新された場合にも確実に読み直すように一度解放する
      @viewmodel.image = Filename::SaveData::SNAPSHOT_n % $1.to_i
    else
      @viewmodel.image = nil
    end
  end

end

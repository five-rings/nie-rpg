=begin
  ヘルプ画面
=end
class Scene::Game::Help < Scene::Game::Base
  include Layout::View
  FILEPATH = Filename::Graphics::Ui::PATH + "/Help"
  FILENAME_d = "help_%d"
  FILENAME_N_d = "help_0%d"
  PAGE_NUM = 3           # ヘルプ画像数
  PAGE_RESERVED_NUM = 3  # 演出用に予約するページ数
  SLIDE_X_DELTA = 64
  ACTOR_ID_TO_SHOW = 1

  def on_initialize
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

    # ヘルプ画像の読み込み
    locale = Itefu::Language::locale
    filebases = [
      "#{FILEPATH}/#{locale}/#{FILENAME_d}",
      "#{FILEPATH}/#{FILENAME_d}",
    ]
    unless Application.savedata_game.system.embodied
      # 非実体化状態用の画像を優先する
      filebases = [
        "#{FILEPATH}/#{locale}/#{FILENAME_N_d}",
        "#{FILEPATH}/#{FILENAME_N_d}",
      ] + filebases
    end
    @bitmaps = 1.upto(PAGE_NUM).map {|i|
      filebases.each do |file|
        begin
          break Itefu::Rgss3::Bitmap.new(file % i)
        rescue Errno::ENOENT
          next
        end
      end
    }

    # @magic: ヘルプの初期ページ
    @page = Itefu::Utility::Math.clamp(0, PAGE_NUM-1, Application.savedata_game.flags.variables[63])
    Application.savedata_game.flags.variables[63] = 0

    # 画面表示用
    @view_root = @scenegraph.add_child(Itefu::SceneGraph::Base)
    @views = PAGE_RESERVED_NUM.times.map {|i|
      page = Itefu::Utility::Math.loop(0, PAGE_NUM-1, @page + i)
      @view_root.add_child(Itefu::SceneGraph::Sprite,
        Graphics.width, Graphics.height,
        @bitmaps[page]
      ).transfer((i - 1) * Graphics.width, nil)
    }

    Itefu::Rgss3::Viewport.new.auto_release {|vp|
      self.viewport = vp
      vp.visible = false
    }

    vm = ViewModel.new
    if Application.savedata_game.system.embodied
      vm.actors = [ Application.savedata_game.actors[ACTOR_ID_TO_SHOW] ]
    else
      vm.actors = [ DummyActor.new ]
    end

    load_layout("menu/help", vm)
    root_control.position(32, 6)

    Graphics.frame_reset
    enter
  end

  def on_finalize
    finalize_layout
    @scenegraph.finalize
    @bitmaps.each(&:dispose)
    @bitmaps.clear
  end

  def update_state
    super
    @scenegraph.update
    @scenegraph.update_interaction
    @scenegraph.update_actualization
  end

  def on_update_main
    input = Application.input
    case
    when input.triggered?(Input::CANCEL)
      Sound.play_cancel_se
      exit
    when input.triggered?(Input::LEFT)
      change_state(State::Slide, 1)
    when input.triggered?(Input::RIGHT), input.triggered?(Input::DECIDE), input.triggered?(Input::CLICK)
      change_state(State::Slide, -1)
    else
      if input.scroll_y < 0
        change_state(State::Slide, 1)
      elsif input.scroll_y > 0
        change_state(State::Slide, -1)
      end
    end
  end

  def on_update
    update_layout
  end

  def on_draw
    @scenegraph.draw
    draw_layout
  end

  def on_draw_main
  end

  def on_state_slide_attach(diff)
    # 次のページ数を計算しておく
    @page = Itefu::Utility::Math.loop(0, PAGE_NUM-1, @page - diff)
    if @page == 1
      self.viewport.ox = Graphics.width * diff
      self.viewport.visible = true
    end
    @slide_x = 0
    @slide_x_delta = SLIDE_X_DELTA * diff
    Sound.play_paging_se
  end

  def on_state_slide_update
    @slide_x += @slide_x_delta
    if @slide_x.abs < Graphics.width
      @view_root.transfer(@slide_x, nil)
      if self.viewport.visible
        self.viewport.ox -= @slide_x_delta
      end
    else
      @view_root.transfer(0, nil)
      PAGE_RESERVED_NUM.times.map {|i|
        page = Itefu::Utility::Math.loop(0, PAGE_NUM-1, @page + i)
        @views[i].reassign_bitmap(@bitmaps[page])
      }
      if @page != 1
        self.viewport.visible = false
      else
        self.viewport.ox = 0
      end

      change_state(Scene::Game::Base::State::Main)
    end
  end

  module State
    module Slide
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
  end

  ViewModel = Struct.new(:actors)
  class DummyActor < Scene::Game::Menu::Top::ViewModel::DummyActor; end

end

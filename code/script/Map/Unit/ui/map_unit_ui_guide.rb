=begin
  画面中に操作ガイドを表示する
=end
class Map::Unit::Ui::Guide < Map::Unit::Base
  def default_priority; end
  include Itefu::Resource::Loader
  include Itefu::Utility::State::Context
  include Itefu::Animation::Player
  FILE_PATH = Filename::Graphics::Ui::PATH_MAP
  attr_reader :auto_open
  
  def map_manager; manager; end

  HEIGHT = 16 + 40*3
  POS_X = 20
  POS_Y = 16 - HEIGHT
  HintColor = Itefu::Color.const(0, 0, 0, 0x7f)
  COUNT_TO_SHOW_SHORT = 60 * 5
  COUNT_TO_SHOW_LONG = 60 * 10

  def count_to_show; @auto_open || Float::INFINITY; end

  def set_auto_open(to_open, to_be_long)
    @auto_open = to_open && (to_be_long ? COUNT_TO_SHOW_LONG : COUNT_TO_SHOW_SHORT)
  end

  def on_initialize(viewport)
    @all_hint = true
    @counter_to_show = 0
    @scenegraph = Itefu::SceneGraph::Root.new

    # -----
    # Base
    res_id_base = load_bitmap_resource(FILE_PATH + "/map_guide")
    base = @scenegraph.add_child(
      SceneGraph::Base,
      48, HEIGHT,
      resource_data(res_id_base),
      0, 245-HEIGHT).tap {|node|
        node.sprite.viewport = viewport
        node.transfer(POS_X, POS_Y)
    }
    
    @anime_in = Itefu::Animation::KeyFrame.new.tap {|anime|
      anime.instance_eval {
        self.default_target = base
        add_key  0, :pos_y, POS_Y, bezier(0,0.63,0,0.99)
        add_key 15, :pos_y, 0
      }
    }
    
    @anime_out = Itefu::Animation::KeyFrame.new.instance_eval {
      self.default_target = base
      add_key  0, :pos_y, 0
      add_key 10, :pos_y, POS_Y
      self
    }
    
    # -----
    # Icons
    res_id_balloon = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BALLOON)

    base.add_child(
      SceneGraph::Icon,
      Itefu::Rgss3::Definition::Balloon::SIZE, Itefu::Rgss3::Definition::Balloon::SIZE,
      resource_data(res_id_balloon),
      64, 32).tap {|node|
        node.sprite.viewport = viewport
        node.anchor(16, 16)
        node.transfer(8, 48)
        node.description = map_manager.lang_message.text(:icon_help)
        node.action = Map::ExitCode::OPEN_HELP
    }

    base.add_child(
      SceneGraph::Icon,
      Itefu::Rgss3::Definition::Balloon::SIZE, Itefu::Rgss3::Definition::Balloon::SIZE,
      resource_data(res_id_balloon),
      96, 0).tap {|node|
        node.sprite.viewport = viewport
        node.anchor(16, 16)
        node.transfer(8, 8)
        node.description = map_manager.lang_message.text(:icon_menu)
        node.action = Map::ExitCode::OPEN_MENU
    }

    base.add_child(
      SceneGraph::Icon,
      Itefu::Rgss3::Definition::Balloon::SIZE, Itefu::Rgss3::Definition::Balloon::SIZE,
      resource_data(res_id_balloon),
      64, 256).tap {|node|
        node.sprite.viewport = viewport
        node.anchor(16, 16)
        node.transfer(8, 88)
        node.description = map_manager.lang_message.text(:icon_preference)
        node.action = Map::ExitCode::OPEN_PREFERENCE
    }

    @anime_focus = Itefu::Animation::KeyFrame.new.instance_eval {
      loop true
      self.default_offset_mode = true
      add_key  0, :offset_y,  0, bezier(0,0.5,0.42,1)
      add_key 20, :offset_y,  3, bezier(0.5,0,1,0.42)
      add_key 40, :offset_y,  0, bezier(0,0.5,0.42,1)
      add_key 60, :offset_y, -3, bezier(0.5,0,1,0.42)
      add_key 80, :offset_y,  0
      self
    }

    # -----
    # Hint
    3.times {|i|
      @scenegraph.add_sprite_id(:"hint#{i}", 120, 22).tap {|node|
        node.sprite.viewport = viewport
        node.sprite.bitmap.font.size = 18
        node.visibility = false
        node.offset(0, -11)
        node.transfer(64, 0)
      }.add_child(SceneGraph::Hint)
    }

    change_state(State::Idle)
  end

  def on_finalize
    clear_state
    finalize_animations
    release_all_resources
    @anime_focus.finalize
    @anime_out.finalize
    @anime_in.finalize
    if @scenegraph
      @scenegraph.finalize
      @scenegraph = nil
    end
  end

  def reset
    @counter_to_show = 0
  end

  def open(all_hint = true)
    @all_hint = all_hint
    @counter_to_show = count_to_show
  end

  # @return [Object] カーソルが重なっているノードを返す
  def update_cursor(x, y)
    hint = nil
    node = @scenegraph.hittest(x, y)
    if node
      # ガイドの帯上にカーソルがある
      if state == State::Idle
        change_state(State::Opening)
      elsif state == State::Showing
        if SceneGraph::Icon === node
          unless @anime_focus.playing? && @anime_focus.default_target.equal?(node)
            @anime_focus.default_target = node
            play_animation(:focus, @anime_focus)
          end
          hint = node
        else
          @anime_focus.finish if @anime_focus.playing?
        end
      end
    else
      # ガイドの帯の外にカーソルがある
      if @x != x || @y != y
        @x = x; @y = y
        reset
      end
      if state == State::Showing && @counter_to_show < count_to_show
        change_state(State::Closing)
      end
    end

    # ラベルの表示を切り替える
    nh = @scenegraph.child(:hint0)
    if hint
      nh.visibility = true
      nh.transfer(nil, y)
      nh.children[0].description = hint.description
      1.upto(3-1) {|i|
        nh = @scenegraph.child(:"hint#{i}")
        nh.visibility = false
      }
    elsif @counter_to_show < count_to_show
      3.times {|i|
        nh = @scenegraph.child(:"hint#{i}")
        nh.visibility = false
      }
    end
    node
  end
  
  # @return [Object] クリックしたボタンを返す
  def operate_click(x, y)
    if state == State::Showing
      node = @scenegraph.hittest(x, y)
      if SceneGraph::Icon === node
        node.sprite.clone.auto_release {|s|
          Application.animation.decide(s)
        }
      end
      node
    end
  end
  
  def on_update
    update_state
    update_animations
    @scenegraph.visibility = Map::SaveData::GameData.system.to_open_menu
    @scenegraph.update
    @scenegraph.update_interaction
    @scenegraph.update_actualization
  end
  
  def on_draw
    draw_state
    @scenegraph.draw
  end

  module SceneGraph
    class Base < Itefu::SceneGraph::Sprite
      include Itefu::SceneGraph::Touchable
      def action; end
    end
    class Icon < Itefu::SceneGraph::Sprite
      include Itefu::SceneGraph::Touchable
      attr_accessor :description
      attr_accessor :action
    end
    class Hint < Itefu::SceneGraph::Node
      attr_accessor :description
      def description=(v)
        @description = v
        render_target.be_corrupted
      end
      def on_draw(target)
        if @description && bitmap = target.buffer
          w = bitmap.width
          h = bitmap.height
          bitmap.fill_rect(0, 0, w, h, HintColor)
          bitmap.draw_text(0, 0, w, h, @description, Itefu::Rgss3::Bitmap::TextAlignment::CENTER)
        end
      end
    end
  end

  module State
    module Idle
      extend Itefu::Utility::State::Callback::Simple
      define_callback :update
    end
    module Opening
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach
    end
    module Showing
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module Closing
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach
    end
  end


  def on_state_idle_update
    if self.auto_open
      @counter_to_show += 1
    end

    if @counter_to_show >= count_to_show
      if state == State::Idle
        # メニューを自動表示
        change_state(State::Opening)
      end
    end
  end

  def on_state_opening_attach
    play_animation(:appearance, @anime_in).finisher {
      change_state(State::Showing)
    }
  end

  def on_state_showing_attach
    if @counter_to_show >= count_to_show
      # 文字ラベルを自動表示
      if @all_hint
        3.times {|i|
          show_hint(i, :"hint#{i}")
        }
      else
        show_hint(0, :hint0)
      end
    end
    @counter_to_show = count_to_show
  end

  def show_hint(icon_index, hint_key)
    hint = @scenegraph.children[0].children[icon_index]
    nh = @scenegraph.child(hint_key)
    nh.visibility = true
    y = hint.screen_y + hint.size_h / 2

    nh.transfer(nil, y)
    nh.children[0].description = hint.description
  end

  def on_state_showing_update
    if @counter_to_show < count_to_show
      3.times {|i|
        nh = @scenegraph.child(:"hint#{i}")
        nh.visibility = false
      }
      change_state(State::Closing)
    end
  end

  def on_state_closing_attach
    @all_hint = true
    @anime_focus.finish
    play_animation(:appearance, @anime_out).finisher {
      change_state(State::Idle)
    }
  end

end

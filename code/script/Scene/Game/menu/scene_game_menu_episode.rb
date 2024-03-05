=begin
  フィールドメニューのこれまでの話
=end
class Scene::Game::Menu::Episode < Scene::Game::Base
  include Layout::View
  
  def on_initialize(menu_message)
    message = Application.language.load_message(:episode)
    @viewmodel = ViewModel.new(message, menu_message)
    load_layout("menu/episode", @viewmodel)

    @scenegraph = Itefu::SceneGraph::Root.new
    @scenegraph.add_child(Itefu::SceneGraph::Sprite,
      Graphics.width, Graphics.height,
      Application.snapshot
    ).tap {|node|
      node.sprite.opacity = 0x7f
    }

    control(:episodelist).tap do |control|

      # 初期カーソルを一番古い未チェックの項目に
      num = @viewmodel.episodes.value.find_index {|item|
        item.new_item
      } || @viewmodel.episodes.value.size - 1
      control.cursor_index = num

      control.add_callback(:cursor_changed, method(:on_cursor_changed))
      push_focus(control)
    end

    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end

  def set_cursor_center(control)
    return unless control
    index = control.cursor_index
    child = control.child_at(index)
    return unless child

    control.scroll_y = (
        child.screen_y +
        child.actual_height / 2
      ) - (
        control.content_top +
        control.content_height / 2
      )
  end

  def exit(*args)
    clear_focus
    super
  end
  
  def on_finalize
    Application.focus.pop
    finalize_layout
    Application.language.release_message(:episode)
    @scenegraph.finalize
  end
  
  def on_update
    update_layout
    @scenegraph.update
  end
  
  def on_draw
    draw_layout
    @scenegraph.draw
  end

  def on_enter_main
  end

  def on_update_main
    if focus.empty?
      exit
    end
  end

  def on_cursor_changed(control, next_index, current_index)

    # 初期スクロール位置をカーソルが画面中央に来るように
    unless @cursor_initialized
      set_cursor_center(control)
      @cursor_initialized = true
    end

    # 表示したエピソードをチェック済みにする
    if next_index && next_index != current_index
      if (c = control.child_at(next_index)) &&  (item = c.item)
        Application.savedata_game.collection.check_episode(item.id)
      end
    end

  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :episodes
    EpisodeItem = Struct.new(:id, :title, :new_item, :text)
    
    def initialize(msg, msg_menu)
      collection = Application.savedata_game.collection

      episodes = msg.each_id.select {|id|
        collection.episode_open?(id)
      }.map {|id|
        title, text = msg.text(id).split("\n", 2)
        EpisodeItem.new(id, title, collection.episode_checked?(id).!, text)
      } #.reverse
      unless Application.savedata_game.system.embodied
        if episodes.size == 1
          # 新規ゲーム開始時のみ切り替える
          episodes[0].title = msg_menu.text(:episode_mask)
        end
      end
      self.episodes = episodes
    end
  end

end

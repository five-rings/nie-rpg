=begin
  フィールドメニューの最初の画面 
=end
class Scene::Game::Menu::Top < Scene::Game::Base
  attr_reader :member_index   # [Fixnum] キャラを選択した場合のindex
  include Layout::View
  
  def on_initialize(message, prev_cursor = nil)
    has_new_episode = Application.savedata_game.collection.episodes.any? {|key, flag|
      flag == false
    }
    @viewmodel = ViewModel.new(message, has_new_episode)

    load_layout("menu/top", @viewmodel)
    control(:sidemenu).tap do |control|
      control.add_callback(:decided, method(:on_decided))
      control.cursor_index = @viewmodel.sidemenu.value.find_index {|item|
        item.id == prev_cursor
      } || 0
    end
    control(:member_list).tap do |control|
      control.add_callback(:decided, method(:on_member_list_decided))
    end

    unless Application.savedata_game.system.embodied
      root_control.child.children[1].openness = 0
    end

    Graphics.frame_reset
    Application.focus.push(self.focus)
    enter
  end

  def exit(*args)
    clear_focus
    super
  end
  
  def on_finalize
    Application.focus.pop
    finalize_layout
  end
  
  def on_update
    update_layout
  end
  
  def on_draw
    draw_layout
  end

  def on_enter_main
    push_focus(:sidemenu)
  end

  def on_update_main
    if focus.empty?
      exit
    end
  end
  
  def on_decided(control, index, x, y)
    if item = control.items[index] 
      case item.id
      when :equip, :skill
        @next_id = item.id
        control.push_focus(:member_list)
      else
        exit(item.id)
      end
    else
      exit
    end
  end

  def on_member_list_decided(control, index, x, y)
    @member_index = index
    exit(@next_id)
  end
  
  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :sidemenu
    attr_observable :actors
    attr_observable :money
    MenuItem = Struct.new(:id, :label, :noticed)
    
    def initialize(msg, has_new_episode)
      if Application.savedata_game.system.embodied
        self.sidemenu = [
          MenuItem.new(:item,  msg.text(:top_side_item)),
          MenuItem.new(:skill, msg.text(:top_side_skill)),
          MenuItem.new(:equip, msg.text(:top_side_equip)),
          MenuItem.new(:episode,  msg.text(:top_side_episode), has_new_episode),
          MenuItem.new(:save,  msg.text(:top_side_save)),
        ]
        self.actors = Application.savedata_game.party.members.map {|actor_id|
          Application.savedata_game.actors[actor_id]
        }
      else
        if Application.savedata_game.collection.some_episode_open?
          self.sidemenu = [
            MenuItem.new(:item,  msg.text(:top_side_item)),
            MenuItem.new(:episode,  msg.text(:top_side_episode), has_new_episode),
          ]
        else
          self.sidemenu = [
            MenuItem.new(:item,  msg.text(:top_side_item)),
          ]
        end

        dummy = DummyActor.new
        self.actors = [dummy]
      end
      self.money = Application.savedata_game.party.money
    end

    class DummyActor < SaveData::Game::Actor
      def initialize
        super(1)
      end

      def level; "?"; end
      def chara_name; "Actor0"; end
      def chara_index; 0; end
      def face_name; ""; end
      def face_index; 0; end
      def job_name; ""; end
      def param_base(id); 0; end
      def param(id); 0; end
      def param_raw(id); 0; end
      def param_equip(id); 0; end
      def luck; 0; end
      def exp; nil; end
      def exp_next; nil; end
    end
  end

end

=begin
  プレイヤーの戦闘行動管理
=end
class Battle::Unit::Action < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::ACTION; end

  def on_initialize(viewport)
    @view = manager
    @viewmodel = ViewModel.new(viewport)
    @actions = []

    @control_actions = @view.add_layout(:right, "battle/action", @viewmodel)
  end

  def clear_actions
    @actions.clear
    @reserved_action = nil
    update_action_list
  end

  def reserve_action(subject, item, icon_index, user_label, action_name, speed, add_move = nil)
    if RPG::Skill === item
      add_move ||= subject.status.additional_move_count
    else
      add_move = 0
    end
    @reserved_action = ViewModel::Action.new(subject, item, icon_index, user_label, action_name, speed, add_move)
    update_action_list
  end

  def cancel_reservation(subject = nil)
    @reserved_action = nil
    if block_given?
      @actions.delete_if {|action|
        if subject.equal?(action.subject)
          yield(action)
        end
      } if subject
    else
      @actions.delete_if {|action| subject.equal?(action.subject) } if subject
    end
    update_action_list
  end

  def add_action_from_reservation(target)
    if @reserved_action
      @reserved_action.target = target
      @reserved_action.selecting = false
      @actions << @reserved_action
      @reserved_action = nil
      @actions.last
    end
  end

  # @caution 明示的にupdate_action_listを呼ぶこと
  def add_action(subject, target, item, icon_index, user_label, action_name, speed, add_move = nil)
    if RPG::Skill === item
      add_move ||= subject.status.additional_move_count
    else
      add_move = 0
    end
    @actions << ViewModel::Action.new(subject, item, icon_index, user_label, action_name, speed, add_move, target)
    @actions.last
  end

  def confirm_action
    @actions.sort_by!(&:speed)
  end

  # @caution 明示的にupdate_action_listを呼ぶこと
  def pop_action
    @actions.pop
  end

  # popしたものを戻す用
  def push_action(action)
    @actions.push action
  end

  # 行動強制などで使用するスキルを変更する
  def replace_action(subject, item, target)
    if action = find_action(subject)
      action.item = item
      action.target = target
      action.label = item.name
      action.action_name = item.name
    end
    action
  end

  # アクションリストの表記をアクション名にする
  def reveal_action(item)
    @viewmodel.actions.value.each do |action|
      if item.equal?(action.item)
        action.action_name = item.name
      end
    end
  end

  # 決定済みの行動についての情報を取得
  def find_action(subject)
    @actions.find {|action|
      subject.equal?(action.subject)
    }
  end

  # 決定済みの行動についてターゲットによって情報を取得
  def find_actions_by
    @actions.find_all {|action|
      yield(action)
    }
  end

  # @return [Array] 特定の対象の行動を取得する
  def select_actions(subject)
    @actions.select {|action|
      subject.equal?(action.subject)
    }
  end

  def empty?
    @actions.empty?
  end

  def action_control(action)
    @control_actions.children.find {|child|
      child.unbox(child.item) == action
    }
  end

  def update_action_list
    @viewmodel.actions.change(true) do |actions|
      actions.clear
      actions.concat @actions
      actions << @reserved_action if @reserved_action
      actions.keep_if {|action|
        action.subject.available?
      }
      actions.sort_by!(&:speed)
    end
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :actions

    class Action 
      include Itefu::Layout::ViewModel
      attr_accessor :subject
      attr_accessor :target
      attr_accessor :item
      attr_accessor :label
      attr_accessor :speed
      attr_accessor :additional_move_count
      attr_accessor :states # アクション実行前に使用者に付与された状態異常
      attr_observable :icon_index, :user_label, :action_name
      attr_observable :selecting


      def initialize(subject, item, icon_index, user_label, action_name, speed, add_move, target = nil)
        self.subject = subject
        self.item = item
        self.label = item.name
        self.icon_index = icon_index
        self.user_label = user_label
        self.action_name = action_name
        self.speed = speed
        if stroke_max = item.special_flag(:stroke_max)
          self.additional_move_count = Itefu::Utility::Math.min(add_move, stroke_max - 1)
        else
          self.additional_move_count = add_move
        end
        if target
          self.target = target
        else
          self.selecting = true
        end
      end

      def unrevealed?
        self.action_name.value.nil?
      end
    end

    def initialize(viewport)
      self.viewport = viewport
      self.actions = []
    end
  end

end


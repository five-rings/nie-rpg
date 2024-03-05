=begin
  マップイベントのBehaviorTree関連
=end
module Map::MapObject::BehaviorTree
  attr_reader :bt_root
  def bt_manager; raise Itefu::Exception::NotImplemented; end

  def clear_behavior_tree_node
    if @bt_root
      @bt_root.die
      @bt_root = nil
    end
  end
  alias :clear_bt_node :clear_behavior_tree_node

  def behavior_tree_context
    @bt_root && @bt_root.context
  end
  alias :bt_context :behavior_tree_context

  def enabled_to_update_behavior_tree?
    true
  end
  alias :enabled_to_update_bt? :enabled_to_update_behavior_tree?

  def setup_behavior_tree(sc_type, context = nil)
    clear_bt_node

    if sc_type
      if context && (context[:sc_type] == sc_type)
        @bt_root = bt_manager.add_bt_tree(Map::Behavior::Root, context)
      else
        @bt_root = bt_manager.add_bt_tree(Map::Behavior::Root, Map::Behavior::Root.default_context(sc_type, self))
      end
    end

    self
  end
  alias :setup_bt :setup_behavior_tree

  def setup_behavior_tree_with_params(sc_type, hash = nil)
    context = Map::Behavior::Root.default_context(sc_type, self)
    context.merge!(hash) if hash
    setup_behavior_tree(sc_type, context)
  end
  alias :setup_bt_with :setup_behavior_tree_with_params

  def merge_behavior_tree_context(patch)
    if context = bt_context
      context.merge!(patch)
    end
    self
  end
  alias :merge_bt_context :merge_behavior_tree_context

  def setup_behavior_tree_with_context(sc_type, patch, context = nil)
    setup_bt(sc_type, context).merge_bt_context(patch)
  end
  alias :setup_bt_with_context :setup_behavior_tree_with_context

end

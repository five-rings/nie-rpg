=begin
 BehaviorTreeのリソースごとのルートノード
=end
class BehaviorTree::RootBase < Itefu::BehaviorTree::Node::ImporterBase
  include Itefu::BehaviorTree::Node
  include BehaviorTree::Node

  # do implement it
  def script_signature; ""; end

  def script_text(script_id)
    load_data(Filename::BehaviorTree::DATA_s % (script_id.to_s)) if script_id
  end

  def initialize(script_id = nil)
    super
  end

  def node_joined(parent)
    if @script_id
      @script_id = "#{script_signature}_#{@script_id}"
    else
      if type = parent.context && parent.context[:sc_type]
        @script_id = "#{script_signature}_#{type}"
      else
        @script_id = script_signature
      end
    end
    super
  end

#ifdef :ITEFU_DEVELOP
  def node_process
    if @need_to_reset
      @need_to_reset = false
      reset_tree
      node_reset
    end
    super
  end

  def reset_tree
    clear_child
    setup_from_script
  end

  def query_to_reset
    @need_to_reset = true
  end

  def tree_label
    script_id.to_s
  end

  def dump_status(indent = 0)
    ITEFU_DEBUG_OUTPUT_NOTICE(" " * indent + tree_label)
    super
  end
#endif

end

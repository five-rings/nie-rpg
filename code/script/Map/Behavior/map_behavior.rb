=begin
=end
module Map::Behavior
  module Actions; end
  module Conditions; end

  class Root < BehaviorTree::RootBase
    def script_signature; "map/map"; end

    def self.default_context(sc_type, map_object)
      {
        :sc_type => sc_type,
        :map_object => map_object,
        # :waypoint_id => 0,
        # :depth_to_find_waypoint => 7,
        :depth_to_find_player => 5,
        # :waypoint_index => nil,
        # :waypoint_prev_id => nil,
        :path => []
      }
    end

    include Actions
    include Conditions

    Importer = Root
    Direction = Itefu::Rgss3::Definition::Direction
    Balloon = Itefu::Rgss3::Definition::Balloon

    def save_data; Application.savedata_game; end
    def sound_manager; Itefu::Sound; end

    def on_node_process
      return Status::RUNNING unless context[:map_object].enabled_to_update_behavior_tree?
      super
    end

#ifdef :ITEFU_DEVELOP
    def tree_label
      mapobj = context[:map_object]
      super + " [#{mapobj.map_id} #{mapobj.event_id}]"
    end
#endif
  end

  module Conditions

    def disabled?(node)
      obj = context[:map_object]
      obj.disabled?
    end

    def moving?(node)
      obj = context[:map_object]
      obj.moving?
    end

    def route_movable?(node)
      obj = context[:map_object]
      obj.moving?.! && obj.auto_walkable?
    end

    def event_running?(node)
      obj = context[:map_object]
      itr = obj.interpreter
      itr && itr.running?
    end

=begin
    def around_waypoint?(node)

      return false unless context[:waypoint_index]
      obj = context[:map_object]
      return false if obj.detached?
      wp = obj.waypoint_manager.waypoint(context[:waypoint_id], context[:waypoint_index])
      if wp
        _, *path = obj.collider.find_path(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y, context[:depth_to_find_waypoint]-1)
        if path.empty?.! || (obj.cell_x == wp.cell_x && obj.cell_y == wp.cell_y)
          true
        end
      end
    end
=end

    def path_empty?(node)
      context[:path].empty?
    end

  end

  module Actions
    class MapAction < Itefu::BehaviorTree::Node::Action

      def find_path_to_player(start_cell_x, start_cell_y, depth = nil)
        obj = context[:map_object]
        return Map::Path::PathArray::UNREACHABLE if obj.detached?
        player = obj.player
        obj.map_instance.find_path(start_cell_x, start_cell_y, player.cell_x, player.cell_y, depth)
      end

=begin
      def find_path_to_waypoint(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth = nil)
        obj = context[:map_object]
        return Map::Path::PathArray::UNREACHABLE if obj.detached?
        calc_vol = 0

        result = obj.collider.find_path_by_los(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, nil)
        return result if result.size >= 2
        calc_vol += result[0]

        result = obj.collider.find_path_by_astar(start_cell_x, start_cell_y, goal_cell_x, goal_cell_y, depth)
        return result if result.size >= 2
        calc_vol += result[0]

        return [calc_vol]
      end
=end
    end

=begin
    # 最初のウェイポイントを設定する    
    class AssignWayPoint < MapAction
      def action
        # puts "assign wp region_id: #{context[:waypoint_id]}"
        fail if context[:waypoint_index]
        obj = context[:map_object]
        fail if obj.detached?
        wps = obj.waypoint_manager.nearers(context[:waypoint_id], obj.cell_x, obj.cell_y)        
        fail unless wps && wps.any? do |wp|
          _, *path = find_path_to_waypoint(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y)
          if path.empty?.!
            context[:waypoint_index] = wp.id
            # puts "default waipoint index is #{wp.id}"
            context[:path] = path
            true
          end
        end
      end
    end
    
    #
    class ReassignWayPoint < MapAction
      def action
        obj = context[:map_object]
        fail if obj.detached?
        wp = obj.waypoint_manager.nearest(context[:waypoint_id], obj.cell_x, obj.cell_y)
        fail unless wp
        fail if context[:waypoint_index] && wp.id == context[:waypoint_index]

        cost, *path = find_path_to_waypoint(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y, context[:depth_to_find_waypoint]-1)
        fail if path.empty?

        wpc = obj.waypoint_manager.waypoint(context[:waypoint_id], context[:waypoint_index])
        if wpc
          cc, _ = find_path_to_waypoint(obj.cell_x, obj.cell_y, wpc.cell_x, wpc.cell_y, context[:depth_to_find_waypoint]-1)
          fail if cc < cost
        end
        
        context[:waypoint_prev_id] = context[:waypoint_index]
        context[:waypoint_index] = wp.id
        # puts "reassign wp #{wp.id}"
      end
    end

=end

    # プレイヤーまでのパスを探索する
    class FindPathToPlayer < MapAction
      def on_initialize(depth = nil)
        @depth = depth || context[:depth_to_find_player]
      end

      def action
        obj = context[:map_object]
        fail if obj.detached?
        player = obj.player

        # 最短距離でも到達できない場合はそもそも探索しない
        fail if @depth < (player.cell_x - obj.cell_x).abs + (player.cell_y - obj.cell_y).abs

        # 到達する可能性があるので経路を探す
        path = find_path_to_player(obj.cell_x, obj.cell_y, @depth)
        fail if path.unreachable?

        # puts "found player"
        context[:path] = path
      end
    end

    class MoveTracePath < MapAction
      def action
        obj = context[:map_object]
        fail if obj.detached?
        suspend while obj.moving?

        dir = context[:path].shift
        fail unless Itefu::Rgss3::Definition::Direction.valid?(dir)

        obj.move(dir)
        suspend while obj.moving?
        fail if context[:path].empty?
      end
    end

=begin
    class MoveAwayFromPath < MapAction
      def action
        obj = context[:map_object]
        fail if obj.detached?
        player = obj.player

        _, dir, _ = obj.collider.find_escape_path_by_astar(obj.cell_x, obj.cell_y, player.cell_x, player.cell_y, 5)
        obj.move(dir) if dir
        suspend while obj.moving?
      end
    end
    
    class BackToWayPoint < MapAction
      def action
        obj = context[:map_object]
        fail if obj.detached?
        wp = obj.waypoint_manager.waypoint(context[:waypoint_id], context[:waypoint_index])
        fail unless wp

        _, *path = find_path_to_waypoint(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y)
        fail if path.empty?

        # puts "back to waypoint #{wp.id}"
        context[:path] = path
      end
    end
    
    class FindNextWayPoint < MapAction
      def action
        obj = context[:map_object]
        fail if obj.detached?
        candidates = obj.waypoint_manager.neighbors(context[:waypoint_id], context[:waypoint_index])
        
        next_id = candidates.select {|id| id != context[:waypoint_prev_id] }.sample
        next_id = context[:waypoint_prev_id] unless next_id
        
        wp = obj.waypoint_manager.waypoint(context[:waypoint_id], next_id)
        fail unless wp

        _, *path = find_path_to_waypoint(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y, context[:depth_to_find_waypoint])
        fail if path.empty?

        # puts "found next waypoint #{wp.id}"
        context[:waypoint_prev_id] = context[:waypoint_index]
        context[:waypoint_index] = wp.id
        context[:path] = path
      end
    end
    
    class FindPrevWayPoint < MapAction
      def action
        fail unless context[:waypoint_prev_id]

        obj = context[:map_object]
        fail if obj.detached?
        wp = obj.waypoint_manager.waypoint(context[:waypoint_id], context[:waypoint_prev_id])
        fail unless wp

        _, *path = find_path_to_waypoint(obj.cell_x, obj.cell_y, wp.cell_x, wp.cell_y, context[:depth_to_find_waypoint])
        fail if path.empty?

        context[:waypoint_prev_id] = context[:waypoint_index]
        context[:waypoint_index] = wp.id
        context[:path] = path
      end
    end

=end
  end

end

=begin
  戦闘画面のレイアウト
=end

_(Canvas) {
  # full field
  _(Canvas) {
    attribute name: :base
  }

  # left pane
  _(Canvas) {
    if debug
      extend Background
      attribute background: Color.Blue
    end
    attribute name: :left,
              width: 150, height: 1.0,
              padding: const_box(5),
              vertical_alignment: Alignment::BOTTOM
  }

  # right pane
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::RIGHT
    _(Canvas) {
      if debug
        extend Background
        attribute background: Color.Red
      end
      attribute name: :right,
                width: 150, height: 1.0,
                padding: const_box(5, 3, 0),
                vertical_alignment: Alignment::BOTTOM
    }
  }

  # top pane
  _(Canvas) {
    attribute name: :top,
              width: 1.0, height: -160
      if debug
        extend Background
        attribute background: Color.Yellow
      end
  }

  # center pane
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER
    _(Canvas) {
      attribute name: :center,
                width: -300, height: -160,
                horizontal_alignment: Alignment::CENTER,
                vertical_alignment: Alignment::BOTTOM
        if debug
          extend Background
          attribute background: Color.Green
        end
    }
  }

  # bottom pane
  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::CENTER,
              vertical_alignment: Alignment::BOTTOM
    _(Canvas) {
      attribute name: :bottom,
                padding: const_box(0, 0, 5),
                width: -300, height: 160
        if debug
          extend Background
          attribute background: Color.White
        end
    }
  }

  # over all
  _(Canvas) {
    attribute name: :all

    _(Composite) {
      extend Cursor
      attribute name: :troop_all
    }
    # _(Composite) {
    #   extend Cursor
    #   attribute name: :party_all
    # }

    _(Canvas) {
      extend Cursor
      attribute name: :troop,
                width: 1.0, height: 1.0
    }

    _(Canvas) {
      extend Cursor
      attribute name: :party,
                width: 1.0, height: 1.0

      def self.next_child_index(operation, child_index)
        nearest = case operation
        when Operation::MOVE_LEFT
          prev_pos_ordered_control(child_at(child_index), self)
        when Operation::MOVE_RIGHT
          next_pos_ordered_control(child_at(child_index), self)
        when Operation::MOVE_UP
          prev_line_ordered_control(child_at(child_index), self)
        when Operation::MOVE_DOWN
          next_line_ordered_control(child_at(child_index), self)
        end
        nearest && find_child_index(nearest)
      end

      def self.prev_line_ordered_control(current, owner)
        return unless current
        base_y = current.screen_y + current.actual_height / 2

        selectables = owner.children.select(&:selectable?)
        candidates = selectables.select {|child| base_y > child.screen_y + child.actual_height / 2 }

        center_x = current.screen_x + current.actual_width / 2
        center_y = base_y
        candidates.min_by {|child|
          (center_x - child.screen_x - child.actual_width/2) ** 2 +
          (center_y - child.screen_y - child.actual_height/2) ** 2
        }
      end

      def self.next_line_ordered_control(current, owner)
        return unless current
        base_y = current.screen_y + current.actual_height / 2

        selectables = owner.children.select(&:selectable?)
        candidates = selectables.select {|child| base_y < child.screen_y + child.actual_height / 2 }

        center_x = current.screen_x + current.actual_width / 2
        center_y = base_y
        candidates.min_by {|child|
          (center_x - child.screen_x - child.actual_width/2) ** 2 +
          (center_y - child.screen_y - child.actual_height/2) ** 2
        }
      end

      def self.prev_pos_ordered_control(current, owner)
        return unless current
        base_x = current.screen_x + current.actual_width / 2

        selectables = owner.children.select(&:selectable?)
        candidates = selectables.select {|child| base_x > child.screen_x + child.actual_width / 2 }
        if candidates.empty?
          return nil
          # @note カーソルをループする場合
          base_x = owner.inner_width + base_x
          candidates = selectables.select {|child| base_x > child.screen_x + child.actual_width / 2 }
        end

        center_x = base_x
        center_y = current.screen_y + current.actual_height / 2
        candidates.min {|a, b|
          r = (center_y - a.screen_y - a.actual_height/2).abs -
              (center_y - b.screen_y - b.actual_height/2).abs
          if r == 0
            r = (center_x - a.screen_x - a.actual_width/2).abs -
                (center_x - b.screen_x - b.actual_width/2).abs
          end
          r
        }
      end

      def self.next_pos_ordered_control(current, owner)
        return unless current
        base_x = current.screen_x + current.actual_width / 2

        selectables = owner.children.select(&:selectable?)
        candidates = selectables.select {|child| base_x < child.screen_x + child.actual_width / 2 }
        if candidates.empty?
          return nil
          # @note カーソルをループする場合
          base_x = base_x - owner.inner_width
          candidates = selectables.select {|child| base_x < child.screen_x + child.actual_width / 2 }
        end

        center_x = base_x
        center_y = current.screen_y + current.actual_height / 2
        candidates.min {|a, b|
          r = (center_y - a.screen_y - a.actual_height/2).abs -
              (center_y - b.screen_y - b.actual_height/2).abs
          if r == 0
            r = (center_x - a.screen_x - a.actual_width/2).abs -
                (center_x - b.screen_x - b.actual_width/2).abs
          end
          r
        }
      end
    }
  }

}


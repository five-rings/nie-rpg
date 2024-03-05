=begin
  これまでのはなし
=end

if debug? && context.nil?
  context = Struct.new(:episodes).new
  EpisodeItem = Struct.new(:title, :new_item, :text)

  lang_eps = Application.language.load_message(:episode)
  self.add_callback(:finalized) {
    Application.language.release_message(:episode)
  }

  context.episodes = lang_eps.each_id.map {|id|
    title, text = lang_eps.text(id).split("\n", 2)
    EpisodeItem.new(title, rand(2) == 0, text)
  } #.reverse
end

message = Application.language.load_message(:menu)
self.add_callback(:finalized) {
  Application.language.release_message(:menu)
}

episode_content = observable("")
# target_margin = observable(box(0))
target_control = observable(nil)
target_align = observable(Alignment::TOP)

_(Grid) {
  add_row_separator 240
  attribute width: 1.0, height: 1.0

  _(Window, 0, 0) {
    attribute width: 1.0,
              grid_row: 0, grid_col: 0
    _(Lineup) {
      extend Drawable
      extend Cursor
      extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
      extend ScrollBar
      attribute name: :episodelist,
                width: 1.0,
                max_height: 1.0,
                scroll_direction: Orientation::VERTICAL,
                scroll_scale: 24+2,
                padding: const_box(5, 5, 5, 0),
                orientation: Orientation::VERTICAL,
                items: binding { context.episodes },
                item_template: proc {|item, item_index|
        _(Label) {
          attribute width: 1.0,
                    margin: const_box(0, 0, 0, 3),
                    padding: const_box(1, 4),
                    font_out_color: item.new_item ? Color.Blue : Color.Black,
                    text: item.title
        }
                }

      _(Label) {
        extend Unselectable
        attribute width: 1.0,
                  item_index: -1,
                  margin: const_box(0, 4, 10),
                  text: message.text(:episode_title)
      } if false

      self.add_callback(:constructed_children) {|control, items|
        episode_content.modify items[0].text unless items.empty?
      }
      self.cursor_decidable = false
      self.add_callback(:cursor_changed) {|control, next_index, current_index|
        if next_index && next_index != current_index
          if c = control.child_at(next_index)
            if item = c.item
              episode_content.modify item.text
            end
            if control.disarranged?
              y = c.screen_y
            else
              y = c.screen_y # - (control.scroll_y || 0)
            end
            target_control.modify c
            if y < Graphics.height / 2
              # target_margin.modify box(y, 0, 0, 0)
              target_align.modify Alignment::TOP
            else
              # target_margin.modify box(0, 0, ::Graphics.height - y - c.actual_height, 0)
              target_align.modify Alignment::BOTTOM
            end
          end
        end
        next_index
      }
    }
  }

  _(Decorator) {
    attribute width: 1.0, height: 1.0,
              grid_row: 1, grid_col: 0,
              vertical_alignment: binding { target_align }

  _(Window, 0, 0) {
    attribute width: 1.0, # height: 1.0,
              margin: binding(nil, proc {|v|
                  if target_align.value == Alignment::TOP
                    if v
                      t = v.screen_y
                      dh = self.desired_height
                      if t + dh > Graphics.height
                        t = Graphics.height - dh
                      end
                      box(t, 0, 0, 0)
                    else
                      const_box(0)
                    end
                  else
                    if v
                      b = Graphics.height - v.screen_y - v.actual_height
                      dh = self.desired_height
                      if b + dh > Graphics.height
                        b = Graphics.height - dh
                      end
                      box(0, 0, b, 0)
                    else
                      const_box(0)
                    end
                  end
                }) { target_control },
              padding: const_box(5, 10)
    _(Text) {
      attribute width: 1.0, # height: 1.0,
                text_word_space: -1,
                text: binding { episode_content }
    }
  }
  }

}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:episodelist)
  }
end


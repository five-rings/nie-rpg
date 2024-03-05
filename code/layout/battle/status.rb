=begin
  戦闘画面のステータス表示
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            padding: box(0, 640-150, 10, 10),
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::BOTTOM

  StateData = Struct.new(:turn_count)
  context = Struct.new(:actors).new
  Status = Struct.new(:active, :face_name, :face_index, :hp, :mhp, :mp, :mmp, :state_data)
  context.actors = [
    Status.new(false, "Actor3", 2, observable(82), 100, 20, 200,  {
      1  => StateData.new(rand(10)),
      3  => StateData.new(rand(10)),
      10 => StateData.new(rand(10)),
      4  => StateData.new(rand(10)),
      20 => StateData.new(rand(10)),
    }),
    Status.new(true, "Actor5", 1, 87, 100, 128, 200, []),
    Status.new(false, "Spiritual", 4, 10, 100,  200, 200, {
      0  => StateData.new(rand(10)),
      7  => StateData.new(rand(10)),
      8  => StateData.new(rand(10)),
    })
  ]
end

font_element = ::Font.new.tap {|font|
  font.size = 16
}

font_state = ::Font.new.tap {|font|
  font.size = 16
  font.bold = true
  font.color = Color.Black
  font.out_color = Color.White
}

database = Application.database
db_states = database.states

proc_gauge_update = proc {|c|
  c.instance_eval {
    if @counter && @counter > 0
      @counter -= 1
      if @counter < 6
        c.corrupt
        if @counter == 0
          @rate_old = nil
        end
      end
    end
  }
}
proc_gauge_changed = proc {|c, name, old|
  if name == :rate
    c.instance_eval {
      @counter = 60
      @rate_old = old
    }
  end
}
proc_gauge = proc {|c, bmp, x, y, w, h|
  c.instance_eval {
    if @rate_old
      if @counter > 6
        r = @rate_old
      else
        r = @rate_old * @counter / 6
      end
      r = Itefu::Utility::Math.min(1.0, r)
      c.draw_background_color(bmp, x, y, content_width * r, h, Color.White)
    end
    c.draw_background_color(bmp, x, y, w, h, Color.Red)
  }
}


_(Lineup){
  attribute width: 1.0,
            orientation: Orientation::VERTICAL,
            items: binding { context.actors },
            item_template: proc {|item, item_index|
  # Status Bar
  _(Sprite, 300, 48+2) {
    extend Animatable
    attribute name: :"status#{item_index}",
              viewport: viewport,
              width: 1.0, height: 48+2,
              opacity: 0,
              margin: const_box(0, (unbox(context.actors).size-item_index)*5, 0, item_index*5),
              padding: const_box(2, 0, 0)

    animation(:in) {
      assign_target(:ox, control.sprite)
      add_key  0, :opacity, 0
      add_key 15, :opacity, 0xff
      add_key  0, :ox, 160
      add_key 10, :ox, 0
    }

  _(Cabinet) {
    extend Background
    attribute width: 1.0, height: 1.0,
              padding: const_box(1),
              fill_padding: true,
              background: const_color(0, 0, 0, 0x7f),
              orientation: Orientation::VERTICAL,
              content_alignment: Alignment::LEFT

    _(Face) {
      extend SpriteTarget
      attribute width: 48, height: 48,
                viewport: viewport,
                tone: binding(const_tone, proc {|v| v ? const_tone : const_tone(0,0,0,0xff) }) { item.active },
                color: binding(Color.Transparent, proc {|v| v ? Color.Transparent : const_color(0,0,0,0x5f) }) { item.active },
                image_source: binding(nil, proc {|v| image(v) }) { item.face_name },
                face_index: binding { item.face_index }
      add_callback(:update) {|c|
        c.sprite.opacity = c.parent.parent.sprite.opacity
        c.sprite.ox = c.parent.parent.sprite.ox
      }
    }

    # States
    _(Lineup) {
      extend SpriteTarget
      ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

      add_callback(:update) {|c|
        c.sprite.opacity = c.parent.parent.sprite.opacity
        c.sprite.ox = c.parent.parent.sprite.ox
      }

      def self.partial_draw(controls)
        # draw all of items even if it is out of bound
        controls.each(&:draw)
      end

      attribute height: 18, #width: 1.0, height: 16,
                margin: const_box(-4, 0, -5),
                viewport: viewport,
                contents_creation: ContentsCreation::IF_LARGE,
                items: binding { item.state_data },
                item_template: proc {|item, item_index|
                  state = db_states[item[0]]
                  next unless state && (state.id == 1 || state.basic_state?)
                  turn_count = Constant::Utility.turn_count_label(item[1].turn_count)
                  if turn_count
      _(CaptionedItem) {
        apply_font(font_state)
        attribute icon_index: state && state.icon_index || 0,
                  icon_size: 18,
                  icon_offset: -2,
                  caption: turn_count,
                  margin: const_box(0, -8, 0, 0),
                  vertical_alignment: Alignment::BOTTOM,
                  # width: 18,
                  height: 18
      }
                  else
      _(Icon) {
        attribute icon_index: state && state.icon_index || 0,
                  margin: const_box(0, 1, 0, 0),
                  width: 18, height: 18
      }
                  end
                }
    }

    # HP
    _(Gauge) {
      hp_obj = BindingObject.new(self, nil, proc {|v|
        unbox(item.hp).to_f / unbox(item.mhp)
      })
      hp_obj.subscribe(item.hp)
      hp_obj.subscribe(item.mhp)

      self.add_callback(:update, &proc_gauge_update)
      self.add_callback(:binding_value_changed, &proc_gauge_changed)

      attribute background: Color.Black,
                gauge: proc_gauge,
                rate: hp_obj,
                margin: const_box(16, 2, 0, 5),
                width: 1.0, height: 4
    }
    _(CaptionedItem) {
      hp_obj = BindingObject.new(self, nil, proc {|v|
        "#{unbox(item.hp)}/#{unbox(item.mhp)}"
      })
      hp_obj.subscribe(item.hp)
      hp_obj.subscribe(item.mhp)

      apply_font(font_element)
      attribute caption: "HP",
                margin: const_box(-16, 0, -4, 5),
                value: hp_obj,
                width: 1.0
    }

    # MP
    _(Gauge) {
      mp_obj = BindingObject.new(self, nil, proc {|v|
        unbox(item.mp).to_f / unbox(item.mmp)
      })
      mp_obj.subscribe(item.mp)
      mp_obj.subscribe(item.mmp)

      attribute background: Color.Black,
                gauge: Color.Blue,
                rate: mp_obj,
                margin: const_box(16, 2, 0, 5),
                width: 1.0, height: 4
    }
    _(CaptionedItem) {
      mp_obj = BindingObject.new(self, nil, proc {|v|
        "#{unbox(item.mp)}/#{unbox(item.mmp)}"
      })
      mp_obj.subscribe(item.mp)
      mp_obj.subscribe(item.mmp)

      apply_font(font_element)
      attribute caption: "MP",
                margin: const_box(-16, 0, 0, 5),
                value: mp_obj,
                width: 1.0
    }
  } # cabinet
  } # sprite
            } # item template

}

add_callback(:layouted) {
  unbox(context.actors).size.times {|i|
    a = view.play_animation(:"status#{i}", :in)
    if i == 0
      a.finisher {
        context.actors[i].hp.value = 10
      }
    end
  }
} if debug?


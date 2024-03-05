=begin
  敵のHPバー
=end

viewport = context && context.viewport

if debug?
  extend Background
  attribute background: Color.Grey,
            fill_padding: true,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

  context = Struct.new(:hp_rate).new(observable(0.5))
end


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
      @counter = 30
      @rate_old = old
    }
  end
}
proc_gauge = proc {|c, bmp, x, y, w, h|
  c.instance_eval {
    hp_rate = unbox(context.hp_rate)
    if @rate_old && hp_rate.nil?.!
      if @counter > 6
        r = @rate_old
      else
        r = @rate_old * @counter / 6
      end
      r = Itefu::Utility::Math.min(1.0, r)
      c.draw_background_color(bmp, x, y, content_width * r, h, Color.White)
    end

    if hp_rate.nil?
      col = Color.Grey
    elsif hp_rate < 0.3
      col = Color.GreenYellow
    else
      col = Color.Red
    end
    c.draw_background_color(bmp, x, y, w, h, col)
  }
}


_(Sprite) {
  extend Background
  ContentsCreation = Itefu::Layout::Control::RenderTarget::ContentsCreation

  extend Animatable
  animation(:in, &Constant::Animation::APPEAR_WINDOW).play_speed = 2
  animation(:out, &Constant::Animation::DISAPPEAR_WINDOW)
  sprite.mirror = true

  attribute name: :life_window,
            background: Color.Black,
            fill_padding: true,
            viewport: viewport,
            contents_creation: ContentsCreation::IF_LARGE,
            opacity: 0,
            padding: const_box(1)

  _(Gauge) {
    self.add_callback(:update, &proc_gauge_update)
    self.add_callback(:binding_value_changed, &proc_gauge_changed)

    attribute background: Color.Black,
              gauge: proc_gauge,
              rate: binding { context.hp_rate },
              width: 1.0, height: 4
  }
}

if debug?
  self.view.control(:life_window).width = 120
  self.add_callback(:layouted) {
    a = self.view.play_animation(:life_window, :in)
    a.finisher {
      context.hp_rate.value = 0.2
    }
  }
end


=begin
=end
class Layout::Control::Dial < Itefu::Layout::Control::Dial
  attr_accessor :cursor_decidable

  def on_decide_effect(index)
    if c = cursor_decidable
      if c.call(self, index)
        Sound.play_decide_se
      else
        Sound.play_disabled_se
      end
    else
      Sound.play_decide_se
    end
    super
  end

  def on_cancel_effect(index)
    Sound.play_cancel_se
    super
  end

  def on_cursor_changing_effect(index)
    Sound.play_select_se
    super
  end

  def on_value_changing_effect(index, new_value, old_value)
    if new_value != old_value
      Sound.play_select_se
    end
    super
  end

end

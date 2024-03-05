=begin
=end
module Layout::Control::Cursor
  include Itefu::Layout::Control::Cursor
  attr_accessor :cursor_decidable

  def on_active_effect(index)
    if @cursored_index
      Sound.play_select_se
    end
    super
  end
  
  def on_decide_effect(index)
    if c = cursor_decidable
      if c.call(self, index)
        Sound.play_decide_se
      else
        Sound.play_disabled_se
      end
    elsif c.nil?
      Sound.play_decide_se
    end
    super
  end
  
  def on_cancel_effect(index)
    Sound.play_cancel_se
    super
  end
  
end

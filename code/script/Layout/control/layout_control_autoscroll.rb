=begin
  内容がはみ出していた場合に自動的にスクロールする
=end
module Layout::Control::AutoScroll
  extend Itefu::Layout::Control::Bindable::Extension
  attr_bindable :scroll_speed_x  # [FixNum] 自動スクロール速度
  attr_bindable :scroll_speed_y  # [FixNum] 自動スクロール速度
  attr_bindable :scroll_wait     # [FixNum] スクロールしはじめるまでのウェイト

  def self.extended(object)
    object.extend Itefu::Layout::Control::Scrollable
  end

  def impl_update
    super
    @scroll_wait_count ||= self.scroll_wait
    if @scroll_wait_count && @scroll_wait_count > 0
      @scroll_wait_count -= 1
      return
    end
    auto_scroll_x
    auto_scroll_y
  end

  def reset_scroll_wait
    @scroll_wait_count = nil
  end

  def auto_scroll_x
    speed = self.scroll_speed_x
    return unless speed
    return if speed == 0

    if speed < 0
      self.scroll_x = Itefu::Utility::Math.max(0, (self.scroll_x || 0 ) + speed)
    elsif speed > 0
      if self.actual_width
        max = self.desired_content_width - self.content_width
        if max > 0
          self.scroll_x = Itefu::Utility::Math.min(max, (self.scroll_x || 0 ) + 1)
        end
      end
    end
  end

  def auto_scroll_y
    speed = self.scroll_speed_y
    return unless speed
    return if speed == 0

    if speed < 0
      self.scroll_y = Itefu::Utility::Math.max(0, (self.scroll_y || 0 ) + speed)
    elsif speed > 0
      if self.actual_height
        max = self.desired_content_height - self.content_height
        if max > 0
          self.scroll_y = Itefu::Utility::Math.min(max, (self.scroll_y || 0 ) + 1)
        end
      end
    end
  end

end

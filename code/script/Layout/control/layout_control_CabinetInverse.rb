=begin
  下から上/右から左に並べるCabinet
=end
class Layout::Control::CabinetInverse < Itefu::Layout::Control::Cabinet
  attr_bindable :content_not_inverse

private

  # 整列
  def impl_arrange(final_x, final_y, final_w, final_h)
    return super if self.content_not_inverse

    return if children.empty?
    controls = children_that_takes_space
    orientator = orientation_storategy
    method_align_phase, method_align_offset = orientator.pola_from_xywh(:pos_x_alignmented, :pos_y_alignmented)
    plalign, oaalign = orientator.pola_from_xywh(horizontal_alignment, vertical_alignment)
    info = @info
    dummy = @dummy_content


    # 子コントロール全体の領域を、このコントロールの描画領域内で整列させる
    dummy.content_width  = info.width
    dummy.content_height = info.height
    dummy.content_left = dummy.content_top = 0
    content_offset = self.send(method_align_offset, self, dummy, oaalign)

    if content_reverse
      controls = controls.reverse_each
      line_sign = -1
      line_index = -1
    else
      line_sign = 1
      line_index = 0
    end
    line_count = 0
    line_length = 0
    calign = content_alignment
    content_length = self.send(orientator::ContentLength)
    break_count = 0
    to_break = false

    # 配置の開始位置
    dummy.content_width,
    dummy.content_height =
      orientator.xywh_from_pola(info.line_lengths[line_index], info.line_amplitudes[line_index])
    child_phase = self.send(method_align_phase,  self, dummy, plalign)
    # 本来の最後の行から計算する
    child_offset = content_offset + info.line_amplitudes.inject(:+) - info.line_amplitudes[line_index]


    # 子コントロールのarrange
    controls.each.with_index do |child, child_index|
      child_full_length = child.send(orientator::DesiredFullLength)
      line_length += child_full_length

      break_pos = @breaking_positions && @breaking_positions[break_count]
      if break_pos && (break_pos < child_index)
        break_count += 1
        to_break = true
      end

      if (line_length > content_length && line_count > 0) || to_break
        # 次の行へ:表示位置を直交方向へずらす
        # 最後尾から戻っていくようにする
        child_offset -= info.line_amplitudes[line_index + line_sign] || 0
        line_length = child_full_length
        line_index += line_sign
        line_count = 0
        dummy.content_width,
        dummy.content_height =
          orientator.xywh_from_pola(info.line_lengths[line_index], info.line_amplitudes[line_index])
        child_phase = self.send(method_align_phase,  self, dummy, plalign)
        to_break = false
      end

      if (calign == Alignment::STRETCH)
        amp = info.line_amplitudes[line_index] - child.margin.send(orientator::Amplitude)
      else
        amp = child.send(orientator::DesiredAmplitude)
      end

      # 整列
      orientator.arrange(
        child,
        # 進行方向の位置
        self.send(method_align_phase, dummy, child, Alignment::LEFT) + child_phase,
        # 直交方向の整列済み位置
        child_offset + self.send(method_align_offset, dummy, child, calign),
        # サイズ
        child.send(orientator::DesiredLength),
        amp
      )
      # 表示位置を進行方向へずらす
      child_phase += child_full_length
      line_count += 1
    end # of each
  end

end


=begin
  Rgss3のデフォルト実装を拡張する  
=end
class RPG::Enemy
  attr_reader :gimmick

  def chiritoribox?; special_flag(:chiritori_variable).nil?.!; end

  Gimmick = Struct.new(:trigger, :threshold, :command, :params)

  def setup_gimmick
    return unless gimmick = special_flag(:gimmick)
    trigger, threshold, command, *params = gimmick.split(",")

    trigger = trigger.intern
    command = command.intern

    if threshold.include?('.')
      threshold = Float(threshold)
    else
      threshold = Integer(threshold)
    end

    case command
    when :state
      # id
      params[0] = Integer(params[0])
    when :graphic
      # hue
      params[1] = (Integer(params[1]) rescue 0 )
      # scale
      params[2] = (Float(params[2]) rescue 1.0)
    else
      ITEFU_DEBUG_OUTPUT_WARNING "Unknown command(#{command}) specified in enemy id.#{self.id}"
    end

    @gimmick = Gimmick.new(trigger, threshold, command, params)
  end

end


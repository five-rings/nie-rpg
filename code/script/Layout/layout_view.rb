=begin  
=end
module Layout::View
  include Itefu::Layout::View::RvData2
  include Itefu::Layout::View::Effect

  Operation = Itefu::Layout::Definition::Operation

  def initialize(*args)
    @layout_path = Filename::Layout::PATH
    super
  end

  def root_control_klass
    Layout::Control::Root
  end

  def add_layout(name, signature, context = nil)
    super(name, signature, context, Layout::Control::Importer)
  end
  
  def handle_input
    return unless input = Application.input
    return unless c = focus.current

    case
    when input.triggered?(Input::DECIDE)
      c.operate Operation::DECIDE
    when input.triggered?(Input::CLICK)
      x = input.position_x
      y = input.position_y
      c.operate Operation::DECIDE, x, y
      @old_input_x = x
      @old_input_y = y
    when input.triggered?(Input::CANCEL)
      c.operate Operation::CANCEL
    when input.repeated?(Input::UP)
      c.operate Operation::MOVE_UP
    when input.repeated?(Input::DOWN)
      c.operate Operation::MOVE_DOWN
    when input.repeated?(Input::LEFT)
      c.operate Operation::MOVE_LEFT
    when input.repeated?(Input::RIGHT)
      c.operate Operation::MOVE_RIGHT
    else
      x = input.position_x
      y = input.position_y
      @old_input_x ||= x
      @old_input_y ||= y
      if @old_input_x != x || @old_input_y != y
        c.operate Operation::MOVE_POSITION, x, y
      end
      @old_input_x = x
      @old_input_y = y
      
      if Itefu::Layout::Control::Scrollable === c
        sy = input.scroll_y
        c.scroll(sy) if sy
      end
    end
  end

end

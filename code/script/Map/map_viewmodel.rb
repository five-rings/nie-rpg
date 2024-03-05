=begin  
=end
class Map::ViewModel
  include Itefu::Layout::ViewModel
  attr_accessor :message_context
  attr_accessor :map_name, :map_notice
  
  Alignment = Itefu::Layout::Definition::Alignment
  
  def initialize
    self.message_context = Message.new
    self.map_name = MapName.new
    self.map_notice = MapPopNotice.new
  end

  def assign_viewport(vp)
    self.map_name.viewport = vp
    self.map_notice.viewport = vp
  end
  
  class Message
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :message
    attr_observable :face_name, :face_index
    attr_observable :background
    attr_observable :alignment
    attr_observable :choices
    attr_observable :digit
    attr_observable :budget

    def initialize
      self.message = ""
      self.face_name = ""
      self.face_index = 0
      self.background = 0
      self.alignment = Alignment::BOTTOM
      self.choices = []
      self.digit = 0
      self.budget = 0
    end
  end

  class MapName
    include Itefu::Layout::ViewModel
    attr_observable :viewport
    attr_observable :map_name

    def initialize
      self.map_name = ""
      self.viewport = nil
    end
  end

  class MapPopNotice
    include Itefu::Layout::ViewModel
    attr_observable :viewport
    attr_observable :message

    def initialize
      self.message = ""
      self.viewport = nil
    end
  end
end

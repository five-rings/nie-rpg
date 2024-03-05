=begin
  ViewportのZを定義する  
=end
class Viewport
#ifdef :ITEFU_DEVELOP
  module Debug
    PERFORMANCE = 0xffff
  end
#endif

  module Display
    ANIME = 0xffe0
    FADE =  0xfff0
  end
  
  module Map
    MAP     = 0x100
    WEATHER = 0x110
    PICTURE = 0x120
    WINDOW  = 0x130
    HUD     = 0x140
  end

  module Battle
    BATTLER = 0x110
    EFFECT  = 0x120
    HUD     = 0x130
    LABEL   = 0x137
    RESULT  = 0x140
    WINDOW  = 0x150
  end
end

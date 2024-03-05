=begin
  ロゴ画面  
=end
class Scene::Game::Boot::Logo < Itefu::Scene::Base
  include Layout::View

  def on_initialize
    Application.focus.push(self.focus)
    load_layout("boot/logo")
    
    @anime = play_animation(:logo, :in).finisher {
      @anime = play_animation(:logo, :wait).finisher {
        @anime = nil
        play_animation(:logo, :out).finisher {
          quit
        }
      }
    }
  end
  
  def on_finalize
    finalize_layout
    Application.focus.pop
  end
  
  def on_update
    update_layout
  end
  
  def on_draw
    draw_layout
  end
  
  def handle_input
    return unless input = Application.input
    case
    when input.triggered?(Input::DECIDE),
         input.triggered?(Input::CANCEL)
      skip_animation
    end
  end
  
  def skip_animation
    @anime.finish if @anime
  end

end
=begin
  初回起動時のタイトル表示画面
=end
class Scene::Game::Title::End < Itefu::Scene::Base
  include Layout::View

  ViewModel = Struct.new(:ending_type, :assigned)

  def on_initialize
    Application.focus.push(self.focus)
    @context = ViewModel.new(Application.savedata_game.flags.ending_type, nil)
    load_layout("boot/end", @context)

    return quit unless @context.assigned

    # 入り演出
    play_animation(:main_title, :show).updater {|anime|
        anime.finish if @skipped
    }.finisher {
      play_animation(:black_belt, :show).updater {|anime|
        anime.finish if @skipped
      }.finisher {
        # 待機演出
        if @skipped
          @skipped = false
          anime_wait = play_raw_animation(:wait, Itefu::Animation::Wait.new(60))
        else
          anime_wait = play_raw_animation(:wait, Itefu::Animation::Wait.new(300))
        end
        anime_wait.updater {|anime|
          anime.finish if @skipped
        }.finisher {
          # 抜け演出
          play_animation(:main_title, :hide)
          play_animation(:sub_title, :hide).finisher {
            quit
          }
        }
      }
    }

    fade = Application.fade
    fade.resolve
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
         input.triggered?(Input::CANCEL),
         input.triggered?(Input::UP),
         input.triggered?(Input::DOWN),
         input.triggered?(Input::LEFT),
         input.triggered?(Input::RIGHT)
      skip_animation
    end
  end
  
  def skip_animation
    @skipped = true
  end

end

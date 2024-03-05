=begin
  テキスト定義データの中身を確認する画面
=end
class Scene::Debug::Menu::Text < Itefu::TestScene::Filer
  
  def preview_klass
    Scene::Debug::Menu::Text::Preview
  end

  def caption
    "Text #{@name}"
  end
  
  def add_system_menu(m)
    m.add_item("Back", :back)
    m.add_item("Convert All", :convert_all) if top_directory?
  end

  def on_item_selected(index, data)
    case data
    when :convert_all
      convert_all
    else
      super
    end
  end
  
  def convert_all
    ITEFU_DEBUG_PROCESS Filename::Tool::CONVERT_TEXT
    ITEFU_DEBUG_OUTPUT_NOTICE "Finished to Convert Text Data"
  end

end

class Scene::Debug::Menu::Text::Preview < Itefu::Scene::DebugMenu
  
  class MyViewModel < ViewModel
    attr_observable :text
    def initialize
      super
      self.text = nil
    end
  end
  
  def viewmodel_klass; MyViewModel; end

  def on_initialize(path, filename)
    @message = Itefu::Language::Message.new(path, filename, nil)
  end
  
  def on_finalize
    @message.finalize
    @message = nil
  end

  def caption
    "Text-Message: #{@message.filename}"
  end

  def menu_list(m)
    m.add_item("Back", :back)
    m.add_separator
    @message.each_id do |id|
      m.add_item(id.to_s, id)
    end
  end

  def on_item_selected(index, data)
    case data
    when :back
      quit
    end
  end

  def cursor_changed(selector, cursor_index, old)
    return unless c = selector.child_at(cursor_index)
    case c.item.data
    when :back
      @viewmodel.text = ""
    else
      change_text(@message.text(c.item.data[0]))
    end
  end
  
  def change_text(text)
    case text
    when Array
      @viewmodel.text = text.map {|t|
        if Symbol === t
          "jump :#{t}"
        else
          ">\n#{t}"
        end
      }.join("\n")
    when Symbol
      @viewmodel.text = ":#{text}"
    else
      @viewmodel.text = text
    end
  end

  def define_layout
    context = @viewmodel
    load_layout(context) {
      _(Grid) {
        add_col_separator 30
        attribute width: 1.0, height: 1.0,
                  margin: const_box(10)
        
        _(Label) {
          attribute grid_row: 0, grid_col: 0,
                    font_size: 24,
                    text: binding { context.caption }          
        }
        
        _(Grid) {
          add_row_separator 160
          attribute width: 1.0, height: 1.0,
                    grid_row: 0, grid_col: 1
          _(Lineup) {
            extend SpriteTarget
            extend Selector
            extend Scrollable.option(:ControlViewer, :CursorScroller)
            attribute name: :menu,
                      grid_row: 0, grid_col: 0,
                      width: 1.0, height: 1.0,
                      vertical_alignment: Alignment::TOP,
                      horizontal_alignment: Alignment::STRETCH,
                      orientation: Orientation::VERTICAL,
                      items: binding { context && context.menu_items },
                      item_template: proc {|item|
             if item
              _(Label) {
                attribute text: item.label,
                          horizontal_alignment: Alignment::LEFT,
                          vertical_alignment: Alignment::CENTER,
                          margin: const_box(0, 0, -2, 10),
                          font_size: 20,
              }
            else
              _(Unselectable, Separator) {
                attribute width: 1, height: 3,
                          separate_color: Itefu::Color.White,
                          padding: const_box(1),
                          margin: const_box(4)
              }
            end
                      }
          }
          _(TextArea) {
            extend SpriteTarget
            attribute width: 1.0, height: 1.0,
                      grid_row: 1, grid_col: 0,
                      text: binding { context && context.text }
          }
        }
      }
      
      self.add_callback(:layouted) {
        view.push_focus(:menu)
      }
    }
    control(:menu).add_callback(:cursor_changed, method(:cursor_changed))
  end

end

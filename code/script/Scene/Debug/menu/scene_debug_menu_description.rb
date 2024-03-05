=begin
  アイテムなどの説明文をチェックする画面
=end
class Scene::Debug::Menu::Description < Itefu::TestScene::Filer
  
  def preview_klass
    Scene::Debug::Menu::Description::Preview
  end

  def caption
    "Description #{@name}"
  end

  def add_entries_to_menu(m)
    case @dir_level
    when 0
      # DB
      m.add_item("Items", :items)
      m.add_item("Weapons", :weapons)
      m.add_item("Armors", :armors)
      m.add_item("Skills", :skills)
    when 1
      db = Application.database.send(@path)
      db.each_with_index do |data, id|
        next unless data
        next if data.name.empty?
        m.add_item("#{id}." + Itefu::Utility::String.shrink(data.name, 8), data)
      end
    end
  end

  def on_item_selected(index, data)
    case data
    when :back
      quit
    when Symbol
      on_directory_selected(data)
    else
      on_file_selected(data)
    end
  end

  def on_directory_selected(data)
    switch_scene(self.class, data, "#{@name}/#{data}", @dir_level + 1, @base_path)
  end
  
  def on_file_selected(data)
    switch_scene(preview_klass, @path, data)
  end

end


class Scene::Debug::Menu::Description::Preview < Itefu::TestScene::Layout::Preview

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_observable :description
    attr_accessor :viewport

    def initialize(text)
      self.description = text
    end
  end

  def root_control_klass
    Layout::Control::Root::Debug
  end

  def on_initialize(path, entry)
    Itefu::Layout::Control::RenderTarget.debug_draw_boundary = false
    @path = path
    @entry = entry
    super("../code/layout","/_sample/test_description.rb")
  end

  def on_finalize
    super
    Itefu::Layout::Control::RenderTarget.debug_draw_boundary = true
  end

  def load_layout(signature, context = nil)
    super(signature, context || ViewModel.new(@entry.description))
  end

end

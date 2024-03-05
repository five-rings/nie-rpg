=begin
=end
class Layout::ViewModel::Dialog
  include Itefu::Layout::ViewModel

  # 選択肢の前に表示する文章
  attr_observable :message

  # 選択肢
  attr_observable :choices

  def initialize
    self.message = ""
    self.choices = []
  end
end


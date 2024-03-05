=begin
  サイドメニュー
=end

if debug? && context.nil?
  context = Struct.new(:sidemenu).new
  MenuItem = Struct.new(:id, :label, :noticed)
  context.sidemenu = [
    MenuItem.new(:back, "Back", false),
    nil,
    MenuItem.new(:item, "Item", true),
  ]
end

_(Window, 0, 0) {
  attribute width: 1.0

  _(Lineup) {
    extend Cursor
    attribute name: :sidemenu,
              width: 1.0,
              horizontal_alignment: Alignment::STRETCH,
              orientation: Orientation::VERTICAL,
               items: binding { context.sidemenu },
              item_template: proc {|item, item_index|
      if item
        _(Label) {
          attribute width: 1.0,
                    horizontal_alignment: Alignment::CENTER,
                    text: item.label
          attribute font_out_color: Color.Blue if item.noticed
        }
      else
        _(Separator) {
          extend Unselectable
          attribute height: 3,
                    margin: const_box(3, 0),
                    padding: const_box(1),
                    separate_color: Color.White,
                    border_color: Color.Black
        }
      end
              }
  }
}

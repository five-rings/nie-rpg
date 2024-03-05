#
# マップ用のルート
#

if debug?
  context = Struct.new(:message_context, :map_name, :map_notice).new
end

_(Canvas) {
  attribute name: :map_root,
            width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::LEFT,
            vertical_alignment: Alignment::TOP

  # メニューUI用の親
  _(Canvas) {
    extend Selector
    attribute name: :map_menu,
              width: 1.0, height: 1.0,
              horizontal_alignment: Alignment::LEFT,
              vertical_alignment: Alignment::TOP
    # マップのキー操作を阻害しないよう一部を無効にする
    self.custom_operation = ->(control, operation, *args) {
      case operation
      when Operation::MOVE_LEFT,
           Operation::MOVE_RIGHT,
           Operation::MOVE_UP,
           Operation::MOVE_DOWN
        nil
      when Operation::DECIDE
        unless args.empty?
          operation
        end
      else
        operation
      end
    }
    # メニューをどれも選んでいないとき用のダミー
    _(Empty) {
      attribute name: :map_menu_empty,
                width: 1.0, height: 1.0
    }
  } if false

  # メッセージウィンドウ
  _(Importer, "message", context.message_context) {
  }

  # マップ名
  _(Importer, "map/name", context.map_name)
  # 通知
  _(Importer, "map/popnotice", context.map_notice)
}

self.add_callback(:layouted) {
  # view.play_animation(:message_window, :in)
  view.play_animation(:message_choices_window, :in).finisher {
    view.push_focus(:message_choices)
  }
} if debug?

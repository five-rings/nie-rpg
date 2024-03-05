=begin
  スキル画面
=end

if debug?
  context = Struct.new(:charamenu, :skills, :description, :dialog_chara, :notice).new
  context.charamenu = (1..3).each.map {|i|
    vm = Layout::ViewModel::CharaMenu.new
    vm.copy_from_actor Application.savedata_game.actors[i]
    vm
  }

  SkillData = Struct.new(:skill, :cost)
  database = Application.database
  db_skills = database.skills

  # db_skills[1].name = "Elemental Reel"
  # db_skills[2].name = "アルクスグランディス"
  context.skills = [
    db_skills[1],
    db_skills[2],
    db_skills[3],
  ] * 7
  context.description = "説明文です"

  context.notice = "お知らせ"
end

_(Grid) {
  add_row_separator 164+8*2
  attribute width: 1.0, height: 1.0,
            horizontal_alignment: Alignment::CENTER,
            vertical_alignment: Alignment::CENTER

  _(Importer, "menu/charamenu", context) {
    attribute grid_row: 0, grid_col: 0
  }

  _(Grid) {
    add_col_separator -120
    attribute width: 1.0, height: 1.0,
              grid_row: 1, grid_col: 0

    _(Window, 0, 0) {
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 0
      _(Tile, 0.5, 1.0/10) {
        extend Drawable
        extend Cursor
        extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
        extend ScrollBar
        attribute name: :skilllist,
                  width: 1.0, height: 1.0,
                  scroll_direction: Orientation::VERTICAL,
                  scroll_scale: 24+2,
                  padding: const_box(0, 5, 0, 0),
                  items: binding { context.skills },
                  item_template: proc {|item, item_index|
                    if item
        _(CaptionedItem) {
          attribute width: 1.0, height: 1.0,
                    margin: const_box(1, 3),
                    icon_index: item.icon_index,
                    caption: Itefu::Utility::String.shrink(item.name, Language::Locale.full? ? 10 : 16),
                    value: item.use_all_mp? ? "∞" : item.mp_cost # @todo
        }
                    else
        _(Empty) {
          attribute width: 1.0, height: 1.0,
                    margin: const_box(1, 3)
        }
                    end

                  }
      }
    }
    _(Window, 0, 0) {
      attribute width: 1.0, height: 1.0,
                grid_row: 0, grid_col: 1
      _(Text) {
        attribute text: binding { context.description },
                  text_word_space: -2,
                  padding: const_box(0, 10, 0, 6),
                  hanging: true,
                  # no_auto_kerning: true,
                  width: 1.0, height: 1.0
      }
    }
  }

  # --------------------------------------------------
  # Target

  _(Importer, "dialog_chara", context.dialog_chara) {
    attribute grid_row: 1, grid_col: 0
  }

  _(Importer, "notice", context) {
    attribute grid_row: 1, grid_col: 0
  }
}

if debug?
  self.add_callback(:layouted) {
    self.view.push_focus(:charamenu)
    self.view.control(:dialog_chara_window).openness = 0xff
  }
end


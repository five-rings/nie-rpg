=begin
  スキルに設定されたアニメーションをプレビューする
=end
class Scene::Debug::Menu::SkillAnimation < Itefu::Scene::DebugMenu
  include Itefu::Layout::View::TextFile
  include Itefu::Resource::Loader

  MENU_ITEM_SIZE = 20
  TARGET_TROOP_ID = 2


  def caption; "Skill Animations"; end

  def viewmodel_klass; ViewModel; end

  class ViewModel < Itefu::Scene::DebugMenu::ViewModel
    attr_accessor :viewport
    attr_observable :actors
    attr_observable :actions
    def initialize
      super
      setup_actors
      setup_actions
    end

    def setup_actors
      db_actor = Application.database.actors
      self.actors = 1.upto(3).map {|actor_id|
        actor = db_actor[actor_id]
        Battle::Unit::Status::ViewModel::Status.new.tap {|status|
          status.face_name = actor.face_name
          status.face_index = actor.face_index
          status.hp = status.mhp = 30
          status.mp = status.mmp = 20
        }
      }
    end

    Action = Struct.new(:icon_index, :user_label, :action_name, :selecting)
    def setup_actions
      db_actor = Application.database.actors

      self.actions = [
        Action.new(9, "b", "かみつく"),
        Action.new(db_actor[1].special_flag(:icon_index), " ", "真・鳴竜剣"),
        Action.new(db_actor[3].special_flag(:icon_index), " ", "スピリットアーツ"),
        Action.new(9, "c", "逃げ出す"),
      ]
    end
  end

  def menu_list(m)
    m.add_item("Exit", nil)
    db_skill = Application.database.skills
    db_skill.each do |skill|
      next unless skill
      next if skill.name.empty?
      m.add_item("#{skill.id} #{skill.name}", skill)
    end
  end

  def initialize(*args)
    @layout_path = "../code/layout"
    @viewports = {
      background:   Itefu::Rgss3::Viewport.new(0, 0, Graphics.width, Graphics.height).tap {|vp| vp.visible = true; vp.z = 0 },
      window:   Itefu::Rgss3::Viewport.new(0, 0, Graphics.width, Graphics.height).tap {|vp| vp.visible = true; vp.z = 1 },
      target:   Itefu::Rgss3::Viewport.new(0, 0, Graphics.width, Graphics.height).tap {|vp| vp.visible = true; vp.z = 0x10 },
      effect:   Itefu::Rgss3::Viewport.new(0, 0, Graphics.width, Graphics.height).tap {|vp| vp.visible = true; vp.z = 0xff },
    }
    @attack_to_enemy = true
    @target_actor_index = @target_enemy_index = 0
    super
    @sprite.z = 0xff
    @sprite.oy = -MENU_ITEM_SIZE/2
    @sprite.viewport = @viewports[:window]
    @scene_root = Itefu::SceneGraph::Root.new
    add_enemies
    add_party
    setup_debug_input
  end

  def on_initialize(default_cursor = nil)
    @default_cursor = default_cursor
  end

  def add_enemies
    db_troop = Application.database.troops
    db_enemy = Application.database.enemies
    troop = db_troop[TARGET_TROOP_ID]
    battle_troop = Battle::Troop.new(TARGET_TROOP_ID, Graphics.width)
    battle_troop.setup_from_database(db_troop, db_enemy)

    centerlly_x = nil
    @scene_enemies = troop.members.map.with_index {|member, index|
      enemy = db_enemy[member.enemy_id]
      id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BATTLER_s % enemy.battler_name, enemy.battler_hue)
      res_data = resource_data(id)
      w = res_data.width
      h = res_data.height
      scale = enemy.special_flag(:scale) || 1
      mirror = enemy.special_flag(:mirror) || false

      if centerlly_x
        # 画面中央にいちばん近い敵を選んでおく
        pos_x = (Graphics.width / 2 - battle_troop.x_from_editor_x(member.x) + w / 2).abs
        if pos_x < centerlly_x
          centerlly_x = pos_x
          @target_enemy_index = index
        end
      else
        centerlly_x = (Graphics.width / 2 - battle_troop.x_from_editor_x(member.x) + w / 2).abs
        @target_enemy_index = index
      end

      @scene_root.add_child(Itefu::SceneGraph::Sprite, w, h, res_data).tap {|node|
        node.transfer(battle_troop.x_from_editor_x(member.x), battle_troop.y_from_editor_y(member.y))
        node.offset(-0.5, -1.0)
        node.anchor(0.5, 1.0)
        node.sprite.viewport = @viewports[:target]
        node.sprite.zoom_x = scale
        node.sprite.zoom_y = scale
        node.sprite.mirror = mirror
      }
    }
  end

  def add_party
    db_actor = Application.database.actors
    viewport = @viewports[:target]
    @scene_actors = 1.upto(3).map.with_index {|actor_id, actor_index|
      # ピラミッド状に並べる
      col = ((actor_index * 2) ** 0.5).to_i
      row = actor_index - (col ** 2 + col) / 2
      if row < 0
        row = col + row
        col -= 1
      end
      y = col
      # x = (row * 2 - col)
      c1 = col % 2
      x = ((row + c1 + 1)/2*2 - c1) * (1 - (row + c1)%2*2)
=begin
      0
     1 2
    4 3 5
   8 6 7 9
=end
      pos_x = viewport.rect.width / 2 + x * 50
      pos_y = viewport.rect.height - 60 + y * 32
      actor = db_actor[actor_id]

      id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::CHARACTERS_s % actor.character_name)
      res_data = resource_data(id)

      graphic = RPG::Event::Page::Graphic.new
      graphic.character_name = actor.character_name
      graphic.character_index = actor.character_index
      graphic.direction = Itefu::Rgss3::Definition::Direction::UP

      @scene_root.add_child_with_id(:sprite, SceneGraph::MapObject, viewport).tap {|node|
        node.transfer(pos_x, pos_y)
        node.sprite.viewport = viewport
        node.apply_graphic(res_data, graphic, true)
        node.offset(-0.5, -1.0)
      }
    }
  end

  def setup_debug_input
    input = Application.input
    semantic = Itefu::Input::Semantics.new(Itefu::Input::Status::Win32).instance_eval do
      define(:hide_menu, Itefu::Input::Win32::Code::VK_TAB)
      define(:change_target, Itefu::Input::Win32::Code::VK_SPACE)
      self
    end
    input.add_semantics(:debug_skill_anime, semantic)
  end

  def on_finalize
    @scene_enemies.clear if @scene_enemies
    @scene_actors.clear if @scene_actors
    if @scene_root
      @scene_root.finalize
      @scene_root = nil
    end
    @viewports.each_value(&:dispose)
    @viewports.clear
    release_all_resources
    input = Application.input
    input.remove_semantics(:debug_skill_anime)
  end

  def on_update
    input = Application.input
    if input.triggered?(:change_target)
      @attack_to_enemy = @attack_to_enemy.!
    end

    diff = 0
    case
    when input.triggered?(Input::LEFT)
      diff = -1
    when input.triggered?(Input::RIGHT)
      diff = 1
    end
    if diff != 0
      if @attack_to_enemy
        @target_enemy_index = Itefu::Utility::Math.loop_size(@scene_enemies.size, @target_enemy_index + diff)
        ITEFU_DEBUG_OUTPUT_NOTICE "change target to enemy #{@target_enemy_index}"
      else
        @target_actor_index = Itefu::Utility::Math.loop_size(@scene_actors.size, @target_actor_index + diff)
        ITEFU_DEBUG_OUTPUT_NOTICE "change target to actor #{@target_actor_index}"
      end
    end

    if input.pressed?(:hide_menu)
      @viewports[:window].visible = false
    else
      @viewports[:window].visible = true
    end
    @viewports.each_value(&:update)
    @scene_root.update
    @scene_root.update_interaction
    @scene_root.update_actualization
  end

  def on_draw
    @scene_root.draw
  end

  def make_targets(skill, targets, current_target_index)
    if Itefu::Rgss3::Definition::Skill::Scope.to_singular?(skill.scope)
      [targets[current_target_index]]
    else
      targets
    end
  end

  def on_item_selected(index, skill)
    return quit unless skill
    db_anime = Application.database.animations
    return unless anime_data = db_anime[skill.animation_id]

    # target を スキル特性を元に決定する
    if @attack_to_enemy
      targets = make_targets(skill, @scene_enemies, @target_enemy_index)
    else
      targets = make_targets(skill, @scene_actors, @target_actor_index)
    end

    # アニメを再生する
    anime = Itefu::Animation::Effect.new(anime_data)

    if Itefu::Rgss3::Definition::Animation::Position.screen?(anime_data.position)
      # 常に一回再生
      anime.assign_target(targets.map(&:sprite), @viewports[:effect])
      anime.auto_finalize
    else
      anime.context = { count: 0, targets: targets }
      target = targets.first
      if @attack_to_enemy
        scale = Application.config.battle_effect_enemy
      else
        scale = Application.config.battle_effect_actor
      end
      anime.assign_target(target.sprite, @viewports[:effect])
      anime.zoom(scale, scale)
      anime.finisher {|a|
        a.context[:count] += 1
        if target = a.context[:targets][a.context[:count]]
          a.assign_target(target.sprite, @viewports[:effect])
          a.zoom(scale, scale)
          play_raw_animation(a, a)
        else
          a.auto_finalize
        end
      }
    end

    anime.offset_z(0xff)
    play_raw_animation(anime, anime)
  end

  def on_canceled
    # 抜ける
  end


  def signature_to_layout(signature)
    super
  rescue
    signature
  end

  def define_layout
    viewport = @viewports[:background]
    viewport_window = @viewports[:window]
    @viewmodel.viewport = viewport
    context = @viewmodel

    load_layout(context) {
      _(Importer, "battle/base") {
        _(Window) {
          extend Background
          attribute opacity: 0,
                    width: 160,
                    height: 230,
                    viewport: viewport_window,
                    background: color(0, 0, 0, 0x7f),
                    fill_padding: true,
                    contents_opacity: 0xff
          self.window.z = 0x10
          _(Lineup) {
            extend Drawable
            extend Cursor
            extend Scrollable.option(:ControlViewer, :CursorScroller, :LazyScrolling)
            extend ScrollBar
            font_item = ::Font.new.tap {|font|
              font.size = MENU_ITEM_SIZE
            }
            attribute name: :menu,
                      width: Size::AUTO, height: 1.0,
                      margin: const_box(0, 0, 0, 20),
                      scroll_direction: Orientation::VERTICAL,
                      orientation: Orientation::VERTICAL,
                      items: binding { context && context.menu_items },
                    item_template: proc {|item, item_index|
              _(Label) {
                apply_font(font_item)
                attribute text: item.label
              }
            }
          }
        }
      }

      self.add_callback(:layouted) {
        view.push_focus(:menu)
      }
    }

    self.control(:base)._(Sprite) {
      self.sprite.z = 0
      attribute viewport: viewport
      _(Image) {
        attribute image_source: image("Graphics/Battlebacks1/Castle"),
                  width: 1.0, height: 1.0
      }
    }

    self.add_layout(:left, "battle/status", @viewmodel, Layout::Control::Importer).tap {|c|
      c.add_callback(:imported) {
        3.times do |i|
          self.play_animation(:"status#{i}", :in)
        end
      }
    }

    self.add_layout(:right, "battle/action", @viewmodel, Layout::Control::Importer)

    if @default_cursor
      index = @viewmodel.menu_items.value.find_index {|m|
        next false unless skill = m.data[0]
        skill.id == @default_cursor
      }
      self.control(:menu).cursor_index = index if index
    end
  end

end

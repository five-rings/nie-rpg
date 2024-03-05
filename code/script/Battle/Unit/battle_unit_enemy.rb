=begin
  戦闘中の敵
=end
class Battle::Unit::Enemy < Battle::Unit::Base
  include Battle::Unit::Battler
  def default_priority; @enemy_index; end
  def unit_id; @enemy_index; end
  def self.unit_id; raise Itefu::Exception::NotSupported; end
  include Itefu::Resource::Loader

  CHIRITORI_EFFECT_PACE = 8

  attr_reader :enemy_label

  def sprite_target; @scene_root.child(:sprite).sprite; end
  def status; @enemy; end
  def pos_x; @scene_root.pos_x; end
  def pos_y; @scene_root.pos_y; end
  def head_x; @scene_root.child(:sprite).screen_x; end
  def head_y; sprite_target.y; end
  def unique_name; "#{@enemy_label}.#{status.name}"; end
  def icon_index; @enemy.icon_index; end
  def icon_label; @enemy_label; end
  def sitaigeri?; true; end
  def effect_scale; Application.config.battle_effect_enemy; end
  def appeared?; @appeared; end

  def available?
    @available && status.alive?
  end
  def movable?; status.unmovable?.!; end

  def show_cursor(visible)
    @scene_root.child(:cursor).visibility = visible
  end

  def skill_id_uncontroll
    Application.config.skill_id_enemy_uncontrolled
  end

  def on_initialize(enemy_index, enemy, viewport, viewport2)
    @enemy_index = enemy_index
    @enemy = enemy
    @available = @appeared = enemy.hidden.!
    @enemy_label = Itefu::Utility::String.letter_number(enemy_index + 1)
    @damages = []

    # @bt_node = create_behavior_tree_node

    @scene_root = Itefu::SceneGraph::Root.new
    @scene_root.transfer(enemy.x, enemy.y)

    id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BATTLER_s % enemy.enemy.battler_name, enemy.enemy.battler_hue)
    res_data = resource_data(id)
    w = res_data.width
    h = res_data.height
    scale = enemy.enemy.special_flag(:scale) || 1
    mirror = enemy.enemy.special_flag(:mirror) || false

    # 敵グラフィック
    @scene_root.add_child_with_id(:sprite, Itefu::SceneGraph::Sprite, w, h, res_data).tap {|node|
      node.offset(-0.5, -1.0)
      node.anchor(0.5, 1.0)
      node.sprite.viewport = viewport
      node.sprite.zoom_x = scale
      node.sprite.zoom_y = scale
      node.sprite.mirror = mirror
      node.sprite.opacity = 0
      play_appearing_animation(node.sprite) if @available
    }

    # カーソル
    if margin_param = @enemy.enemy.special_flag(:cursor_margin)
      ct, cr, cb, cl = margin_param.split(",").map {|v| Integer(v) } rescue nil
    end
    ct ||= 0; cr ||= 0; cb ||= 0; cl ||= 0
    ws = (w*scale).to_i # @todo 左右はみ出さない処理も本来は入れるべき
    hs = Itefu::Utility::Math.min((h*scale).to_i, enemy.y)
    @scene_root.add_child_with_id(:cursor, SceneGraph::Cursor, ws+cr+cl, hs+ct+cb).tap {|node|
      node.visibility = false
      node.offset(-0.5, -1.0)
      node.sprite.viewport = viewport
      node.transfer((cr-cl)/2, cb)
      if color = Battle::SaveData::GameData.system.battle_cursor
        node.sprite.color = color
      end
    }

    setup_chiritori_effect

    add_layout_entry(manager, viewport, viewport2, w, h, scale)
  end

  def setup_chiritori_effect
    return unless @enemy.enemy.chiritoribox?
    return unless value = @enemy.enemy.special_flag(:chiritori_effect)
    name, *params = value.split(",")
    begin
      params.map! {|v| Integer(v) }
    rescue
      return
    end

    graphic = RPG::Event::Page::Graphic.new
    graphic.character_name  = name
    graphic.character_index = params[0] if params[0]
    graphic.direction       = params[1] if params[1]
    graphic.pattern         = params[2] # nil = anime
    @graphic_chiritori = graphic
  end

  module EnemyData
    attr_reader :enemy_status
    attr_reader :enemy_unit
  end

  def add_layout_entry(view, viewport, viewport2, w, h, scale)
    enemy = @enemy
    unit = self
    @viewmodel = ViewModel.new(viewport)

    @cursor_control = view.control(:troop).add_child_control(Itefu::Layout::Control::Canvas).tap do |c|

      c.extend(EnemyData).instance_eval {
        @enemy_status = enemy
        @enemy_unit = unit
      }
      c.attribute unselectable: unit.available?.!,
                  visibility: unit.available? ? Itefu::Layout::Definition::Visibility::VISIBLE : Itefu::Layout::Definition::Visibility::COLLAPSED,
                  margin: c.box(enemy.y-h, 0, 0, enemy.x-w/2),
                  width: w, height: h,
                  horizontal_alignment: Itefu::Layout::Definition::Alignment::CENTER,
                  vertical_alignment: Itefu::Layout::Definition::Alignment::BOTTOM

      c.add_callback(:select_activated) {
        unit.show_cursor(true)
      }
      c.add_callback(:select_deactivated) {
        unit.show_cursor(false)
      }
      c.add_callback(:select_decided) {
        unit.show_cursor(false)
      }
      c.add_callback(:select_canceled) {
        unit.show_cursor(false)
      }

      @viewmodel.viewport = viewport2
      @damage_control = view.add_layout(c, "battle/damage", @viewmodel)
      @viewmodel.viewport = viewport
      @life_control = view.add_layout(c, "battle/life", @viewmodel)
      @life_control.width = (w * scale).to_i
    end

    setup_damage_animation
    setup_life_animation
  end

  def setup_life_animation
    if Battle::SaveData::SystemData.collection.enemy_known?(status.enemy_id)
      @anime_life = Itefu::Animation::Sequence.new.tap {|a|
        a.add_animation(@life_control.animation_data(:in))
        a.add_animation(Itefu::Animation::Wait.new(90))
        a.add_animation(@life_control.animation_data(:out))
      }
    else
      @anime_life = Itefu::Animation::Sequence.new.tap {|a|
        a.add_animation(@life_control.animation_data(:in))
        k = a.add_animation(Animation::Damage::Short.new(@life_control, :oy))
        a.add_animation(Itefu::Animation::Wait.new(90 - k.max_frame_count))
        a.add_animation(@life_control.animation_data(:out))
      }
    end
  end

  def take_damage(damage)
    case damage
    when Numeric
      return if damage <= 0

      rate = status.hp.to_f / status.mhp
      unless @anime_life.playing? && @viewmodel.hp_rate.value == rate
        manager.play_raw_animation(@anime_life, @anime_life)
      end
      if Battle::SaveData::SystemData.collection.enemy_known?(status.enemy_id)
        @viewmodel.hp_rate = rate
      else
        @viewmodel.hp_rate = nil
      end

      # 一度殴られたら逃げる設定の場合
      if @enemy.enemy.chiritoribox?
        vi = @enemy.enemy.special_flag(:chiritori_variable) + @enemy_index
        Battle::SaveData.change_variable(vi, damage)
        db_skills = @manager.database.skills
        if skill = db_skills[3] # @magic: skill id.3: 逃げる
          manager.force_add_action(self, skill, Itefu::Rgss3::Definition::Skill::Scope::MYSELF)
        end

        # エフェクトを放つ
        emit_chiritori_effects(damage)
      end

    end
  end

  def emit_chiritori_effects(damage)
    return unless @graphic_chiritori
    count = Application.config.battle_chiritori_count.call(damage) || Itefu::Utility::Math.min(damage/200+1, 20)
    viewport = @viewmodel.viewport

    count.times do
      id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::CHARACTERS_s % @graphic_chiritori.character_name)
      res_data = resource_data(id)
      node = @scene_root.add_child(SceneGraph::MapObject)
      node.sprite.viewport = viewport
      node.apply_graphic(res_data, @graphic_chiritori, true)
      unless node.pattern
        node.pattern = rand(Itefu::Rgss3::Definition::Tile::PATTERN_MAX)
        node.auto_anime = CHIRITORI_EFFECT_PACE
      end
      node.offset(-0.5, -0.5)
      if color_param = @enemy.enemy.special_flag(:chiritori_color)
        begin
          node.sprite.color = Itefu::Color.create(*color_param.split(",").map {|v| Integer(v) })
        rescue
        end
      end
      anime = Application.config.battle_chiritori_anime.call(count, damage, node)
      anime.default_target = node
      manager.play_raw_animation(anime, anime)
    end
  end

  def on_finalize
    if @scene_root
      @scene_root.finalize
      @scene_root = nil
    end
    release_all_resources
  end

  def on_update
    if @enemy.dead?
      play_dying_animation unless @dead
      @dead = true
    else
      status.add_hp(0)  # clamp within mhp
      status.add_mp(0)  # clamp within mmp
    end
    @scene_root.update
    @scene_root.update_interaction
    @scene_root.update_actualization
    process_damage
  end

  def on_draw
    @scene_root.draw
  end

  def friend_unit; manager.troop_unit; end
  def opponent_unit; manager.party_unit; end

  def make_target
    @target_itself ||= proc {
      self.available? ? [self] : []
    }
  end

  # このターゲットが死ぬなどしたとき代わりの対象を選ぶ
  def make_target_surely(troop_unit)
    @target_surely ||= proc {
      t = make_target.call
      if t.empty?
        t = troop_unit.make_target_head.call
      end
      t
    }
  end

  # 行動追加回数分 make_actionを呼ぶ
  def make_actions(action_unit)
    # 通常の行動
    make_action(action_unit)
    # @note 敵のadditional_move_countは0になるので素値を参照する
    amx = status.additional_move_x
    # 確定の追加行動
    (amx / 100).times {
      make_action(action_unit)
    }
    # 確率の追加行動
    if rand(100) < (amx % 100)
      make_action(action_unit)
    end
  end

  def make_action(action_unit)
    return unless available?

    # make action by behavior tree
    # @bt_node.update

    # @note 敵がスキル封印されている場合は選んだ上で実行時にMISSになる仕様を選択したのでここではスキル封印についてなにもしていない

    unless @skill_to_use && @target_to_action
      db_skills = @manager.database.skills
      scope = case status.state_restriction
      when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_OPPONENT
        @skill_to_use = db_skills[skill_id_uncontroll]
        @target_to_action = opponent_unit.make_target_random(1, sitaigeri?).call.first.make_target
      when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_SOMEONE
        @skill_to_use = db_skills[skill_id_uncontroll]
        if rand(2) == 0
          @target_to_action = opponent_unit.make_target_random(1, sitaigeri?).call.first.make_target
        else
          @target_to_action = friend_unit.make_target_random(1).call.first.make_target
        end
      when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_FRIEND
        @skill_to_use = db_skills[skill_id_uncontroll]
        @target_to_action = friend_unit.make_target_random(1).call.first.make_target
      when Itefu::Rgss3::Definition::State::Restriction::UNMOVABLE
        # do nothing
      else
        make_default_action(action_unit)
      end
    end
    return unless @skill_to_use && @target_to_action

    skill = @skill_to_use
    if Battle::SaveData::SystemData.collection.enemy_skill_proved?(status.enemy.id, skill.id) && skill.secret_name?.!
      name = skill.name
    else
      name = nil
    end
    speed = Game::Agency.action_speed(status) + skill.speed
    action_unit.add_action(self, @target_to_action, skill, self.icon_index, icon_label, name, speed)

    @skill_to_use = @target_to_action = nil
  end

  # 未知のスキルを既知にする
  def reveal_skill(target, skill_id)
    return false unless target.available?
    return false if Battle::SaveData::SystemData.collection.enemy_skill_proved?(status.enemy.id, skill_id)

    if Game::Agency.check_revealing_action(status, target.status)
      Battle::SaveData::SystemData.collection.prove_enemy_skill(status.enemy.id, skill_id)
      true
    else
      false
    end
  end

  def consume_mp_if_possible(cost)
    if cost <= status.mp
      status.add_mp(-cost)
    end
  end

  def appear
    return if @available

    play_appearing_animation
    @cursor_control.unselectable = false
    @cursor_control.visibility = Itefu::Layout::Definition::Visibility::VISIBLE
    @available = @appeared = true
  end

  def escape
    return false unless @available

    play_escaping_animation
    @cursor_control.unselectable = true
    @cursor_control.visibility = Itefu::Layout::Definition::Visibility::COLLAPSED
    @available = false
    true
  end

  def play_appearing_animation(sprite_target = self.sprite_target)
    anime = Itefu::Animation::Battler.new(Itefu::Animation::Battler::EffectType::APPEAR).auto_finalize
    anime.sprite = sprite_target
    manager.play_raw_animation(anime, anime)
  end

  def play_escaping_animation(sprite_target = self.sprite_target)
    anime = Itefu::Animation::Battler.new(Itefu::Animation::Battler::EffectType::DISAPPEAR).auto_finalize
    anime.sprite = sprite_target
    manager.play_raw_animation(anime, anime)
    manager.sound.play_escape_se if manager.sound
  end

  def play_damage_animation
    anime = Animation::Damage.new(@scene_root.child(:sprite))
    manager.play_raw_animation(anime, anime)
  end

  def play_dying_animation(sprite_target = self.sprite_target)
    anime_type = case status.collapse_type
    when Itefu::Rgss3::Definition::Feature::CollapseType::BOSS
      Itefu::Animation::Battler::EffectType::BOSS_COLLAPSE
    when Itefu::Rgss3::Definition::Feature::CollapseType::INSTANT
      Itefu::Animation::Battler::EffectType::INSTANT_COLLAPSE
    when Itefu::Rgss3::Definition::Feature::CollapseType::INCOLLAPSABLE
      nil
    else
      Itefu::Animation::Battler::EffectType::COLLAPSE
    end
    return unless anime_type

    @anime_dying = anime = Itefu::Animation::Battler.new(anime_type).auto_finalize
    anime.sprite = sprite_target
    manager.play_raw_animation(anime, anime)
  end

  def playing_dying_animation?
    @anime_dying && @anime_dying.playing?
  end

  def transform(enemy_id)
    return unless enemy = manager.database.enemies[enemy_id]
    @enemy.transform(enemy)
    change_graphic(enemy.battler_name, enemy.battler_hue)

    db_c = Battle::SaveData::SystemData.collection
    db_c.discover_enemy(enemy_id)
  end

  def change_graphic(name, hue = 0, scale = nil)
    id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::BATTLER_s % name, hue)
    res_data = resource_data(id)
    w = res_data.width
    h = res_data.height

    node = @scene_root.child(:sprite)
    node.reassign_bitmap(res_data, w, h)
    if scale
      node.sprite.zoom_x = scale
      node.sprite.zoom_y = scale
      @scene_root.child(:cursor).resize(w*scale, h*scale)
      @life_control.width = (w * scale).to_i
    else
      @scene_root.child(:cursor).resize(w, h)
      if w > @life_control.width
        # @todo 小さくする場合はHPゲージの表示位置がズレてしまうバグが未調査のまま残っている
        @life_control.width = w
      end
    end

    @cursor_control.width       = w
    @cursor_control.height      = h
    @cursor_control.margin.left = @enemy.x - w/2
    @cursor_control.margin.top  = @enemy.y - h
  end

  def on_unit_state_changed(old)
    case unit_state
    when Battle::Unit::State::TURN_END
      status.ease_buffs
      status.ease_debuffs
      status.ease_states_due_to_timing(Itefu::Rgss3::Definition::State::AutoRemovalTiming::TURN) {|state, data|
        manager.push_repeat_skill_by_state(self, state, data)
      }
      status.remove_states_due_to_eased_out {|state|
        manager.push_chain_skill_by_state(self, state)
        true
      }
    when Battle::Unit::State::COMMANDING
      update_selector
    when Battle::Unit::State::QUIT
      status.clear_all_buffs
      status.clear_all_debuffs
    end
  end

  def take_auto_heal
    status.take_hpr_positive
  end

  def take_slip_damage
    status.take_hpr_negative
  end

  def regenerate_mp
    status.recover_mp
  end

  def make_default_action(action_unit)
    myactions = action_unit.select_actions(self)
    index = Itefu::Utility::Array.weighted_randomly_select(@enemy.actions) {|action|
      next 0 if status.skill_disabled?(action.skill_id)
      next 0 unless action_in_condition?(action, myactions)
      action.rating
    }
    return unless index

    action = @enemy.actions[index]
    db_skills = @manager.database.skills
    return unless skill = db_skills[action.skill_id]
    @skill_to_use = skill

    make_default_target(skill)
  end

  def make_default_target(skill)
    @target_to_action = make_target_by_skill(skill)
  end

  def convert_damagetype(damagetype)
    if damagetype.resisted
      # @note 敵側は意図して設定した耐性しかないので、耐性値を持っていれば強い耐性演出を使うことにする
      damagetype.blocked = true
    end
    super
  end



private

=begin
  def create_behavior_tree_node
    node = Itefu::BehaviorTree::Node::Root.new
    node
  end
=end

  def update_selector
    @cursor_control.unselectable = self.available?.!
    @cursor_control.visibility = self.available? ? Itefu::Layout::Definition::Visibility::VISIBLE : Itefu::Layout::Definition::Visibility::COLLAPSED
  end

  def action_in_condition?(action, myactions)
    # mpがあるかチェック
    # db_skills = @manager.database.skills
    # return false unless skill = db_skills[action.skill_id]
    # return false if status.mp < skill.mp_cost

    # 二回行動などで行動が重複しないようチェック
    if myactions.find {|myact|
      RPG::Skill === myact.item && action.skill_id == myact.item.id
    }
      return false
    end

    case action.condition_type
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::ALWAYS
      true
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::TURN
      if action.condition_param2 == 0
        manager.turn_count == action.condition_param1
      else
        t = manager.turn_count - action.condition_param1
        t >= 0 && t % action.condition_param2 == 0
      end
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::HP
      status.mhp * action.condition_param1 <= status.hp && status.hp <=  status.mhp * action.condition_param2
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::MP
      status.mmp * action.condition_param1 <= status.mp && status.mp <=  status.mmp * action.condition_param2
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::STATE
      status.in_state_of?(action.condition_param1)
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::PARTY_LEVEL
      raise Itefu::Exception::NotSupported
    when Itefu::Rgss3::Definition::Enemy::Action::ConditionType::SWITCH
      Battle::SaveData.switch(action.condition_param1)
    else
      false
    end
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :value
    attr_observable :size
    attr_observable :color, :out_color
    attr_observable :damage_infos
    attr_observable :hp_rate

    def initialize(viewport)
      self.viewport = viewport
      self.value = ""
      self.size = 20
      self.color = Itefu::Color.Red
      self.out_color = Itefu::Color.Black
      self.damage_infos = []
      self.hp_rate = 1.0
    end
  end

end


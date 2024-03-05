=begin
  戦闘中の味方
=end
class Battle::Unit::Actor < Battle::Unit::Base
  include Battle::Unit::Battler
  def default_priority; @actor_index; end
  def unit_id; @actor_index; end
  def self.unit_id; raise Itefu::Exception::NotSupported; end
  include Itefu::Resource::Loader

  SIZE = Itefu::Rgss3::Definition::Tile::SIZE
  CURSOR_PADDING = 5
  ANIME_SPEED = 20

  def sprite_target; @scene_root.child(:sprite).sprite; end
  def status; manager.party.status(unit_id); end
  def pos_x; @scene_root.pos_x; end
  def pos_y; @scene_root.pos_y; end
  def head_x; @scene_root.child(:sprite).screen_x; end
  def head_y; @scene_root.child(:sprite).screen_y - SIZE; end

  attr_reader :action_speed   # あるターンの行動速度
  def icon_index; @party.icon_index(@actor_index); end
  def icon_label; " "; end
  attr_accessor :active       # 待機モーションをとるか

  def available?
    @party.alive?(@actor_index)
  end
  def movable?; @party.unmovable?(@actor_index).!; end
  def has_inventory?; true; end
  def change_graphic(*args); raise Itefu::Exception::NotSupported; end
  def effect_scale; Application.config.battle_effect_actor; end
  def auto_action?; @auto_action; end

  def hate
    if available?
      status.hate
    else
      # 戦闘不能時は、装備品の狙われ値は除外する
      status.hate_raw + Application.config.hate_in_dead
    end
  end

  def has_magic?
    status.equipped_magic?
  end

  def show_cursor(visible)
    @scene_root.child(:cursor).visibility = visible
  end

  def on_initialize(actor_index, party, viewport, viewport2)
    @party = party
    @actor_index = actor_index
    @damages = []
    @anime_pattern = 0
    @active = false
    @escape_count = 0
    @action_speed = 0

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

    @scene_root = Itefu::SceneGraph::Root.new
    @scene_root.transfer(pos_x, pos_y)

    @scene_root.add_child_with_id(:sprite, SceneGraph::MapObject, viewport).tap {|node|
      node.sprite.viewport = viewport
    }
    update_graphic_to_alive

    @scene_root.add_child_with_id(:cursor, SceneGraph::Cursor, SIZE+CURSOR_PADDING*2, SIZE+CURSOR_PADDING*2).tap {|node|
      node.transfer(nil, CURSOR_PADDING)
      node.visibility = false
      node.offset(-0.5, -1.0)
      node.sprite.viewport = viewport
      if color = Battle::SaveData::GameData.system.battle_cursor
        node.sprite.color = color
      end
    }

    add_layout_entry(manager, viewport, viewport2, pos_x, pos_y, SIZE, SIZE)
  end

  module ActorData
    # attr_reader :actor_status
    attr_reader :actor_unit
  end

  def add_layout_entry(view, viewport, viewport2, pos_x, pos_y, w, h)
    unit = self
    @viewmodel = ViewModel.new(viewport)

    view.control(:party).add_child_control(Itefu::Layout::Control::Canvas).tap do |c|
      c.extend(ActorData).instance_eval {
        @actor_unit = unit
      }
      c.attribute unselectable: false,
                  margin: c.box(pos_y-h, 0, 0, pos_x-w/2),
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
      def c.impl_draw
        # draw all of items even if it is out of bound
        children_that_takes_space.each(&:draw)
      end

      @viewmodel.viewport = viewport2
      @damage_control = view.add_layout(c, "battle/damage", @viewmodel)
      # @state_list_control = view.add_layout(c, "battle/state_list", @viewmodel)
      @viewmodel.viewport = viewport
      @state_control = view.add_layout(c, "battle/state", @viewmodel)
    end

    setup_damage_animation
  end

  def on_finalize
    if @scene_root
      @scene_root.finalize
      @scene_root = nil
    end
    release_all_resources
  end

  def on_update
    if @party.dead?(@actor_index)
      unless @dead
        update_graphic_to_dead
        @dead = true
        @viewmodel.state_data = []
      end
    else
      if @dead
        update_graphic_to_alive
        @dead = false
      end
      status.add_hp(0)  # clamp within mhp
      status.add_mp(0)  # clamp within mmp
      # deep copy して値が変わったら更新する
      @viewmodel.state_data = Marshal.load(Marshal.dump(@party.state_data(@actor_index))) if @viewmodel.state_data.value != @party.state_data(@actor_index)
    end
    if @active && @dead.!
      @anime_pattern = Itefu::Utility::Math.loop(0, 4*ANIME_SPEED, @anime_pattern + 1)
      node = @scene_root.child(:sprite)
      node.pattern = @anime_pattern / ANIME_SPEED
    end
    @scene_root.update
    @scene_root.update_interaction
    @scene_root.update_actualization
    process_damage
  end

  def on_draw
    @scene_root.draw
  end

  def update_graphic(chara_name, chara_index, dir = Itefu::Rgss3::Definition::Direction::UP)
    id = load_bitmap_resource(Itefu::Rgss3::Filename::Graphics::CHARACTERS_s % chara_name)
    res_data = resource_data(id)

    graphic = RPG::Event::Page::Graphic.new
    graphic.character_name = chara_name
    graphic.character_index = chara_index
    graphic.direction = dir

    node = @scene_root.child(:sprite)
    node.apply_graphic(res_data, graphic, true)
    node.offset(-0.5, -1.0)
  end

  def update_graphic_to_dead
    actor = @party.actor_data(@actor_index)
    return unless v = actor.special_flag(:dead)
    chara_name, chara_index, dir, pattern, _ = v.split(",")
    chara_index = Integer(chara_index) rescue nil
    dir = Integer(dir) rescue nil
    return unless chara_name && chara_index && dir

    update_graphic(chara_name, chara_index, dir)
  end

  def update_graphic_to_alive
    update_graphic(@party.chara_name(@actor_index), @party.chara_index(@actor_index))
  end

  def post_action
    # 身代わりの形代の消費処理
    if status.in_state_of?(181) # @magic: 身代わり削除用の隠しステート
      status.remove_state(181)

      position, item = status.equipments.find {|k, equip|
        equip && equip.special_flag(:equip) == :migawari
      }
      if position
        # 対応するアイテムを減らす
        db_items = @manager.database.items
        item_id = item.special_flag(:item_id)
        @party.consume_item_by_id(item_id)
=begin
        event_id = Integer(item.special_flag(:common_event)) rescue nil
        if event_id && (event = @manager.database.common_events[event_id])
          @manager.interpreter_unit.start_battle_event(nil, event_id, event.list)
        end
=end
        # 装備から削除する
        status.remove_equip(position)
      end
    end
  end


  def friend_unit; manager.party_unit; end
  def opponent_unit; manager.troop_unit; end

  def make_target
    if available?
      @target_itselc ||= proc {
        # 敵は死体蹴りしてくる
        # self.available? ? [self] : []
        [self]
      }
    else
      @target_dead ||= proc {
        self.available? ? [] : [self]
      }
    end
  end

  def make_target_friendly
    if available?
      @target_alive ||= proc {
        self.available? ? [self] : []
      }
    else
      @target_dead ||= proc {
        self.available? ? [] : [self]
      }
    end
  end

  # 制御不能時の自動行動
  def make_action(action_unit)
    @auto_action = false
    return unless available?

    # 自動戦闘で使用するスキル
    if Itefu::Rgss3::Definition::State::Restriction.upset?(status.state_restriction)
      skill_id = Integer(status.actor.special_flag(:uncontroll)) rescue 0
    elsif status.auto_battle?
      skill_id = Integer(status.actor.special_flag(:auto_battle)) rescue 0
    else
      return
    end
    db_skills = @manager.database.skills
    return unless skill = db_skills[skill_id]

    # ターゲットの選択
    target_to_action = case status.state_restriction
    when Itefu::Rgss3::Definition::State::Restriction::UNMOVABLE
      # 行動不能
    when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_OPPONENT
      opponent_unit.make_target_random(1).call.first.make_target
    when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_SOMEONE
      if rand(2) == 0
        opponent_unit.make_target_random(1).call.first.make_target
      else
        friend_unit.make_target_random(1).call.first.make_target
      end
    when Itefu::Rgss3::Definition::State::Restriction::ATTACK_TO_FRIEND
      friend_unit.make_target_random(1).call.first.make_target
    else
      if status.auto_battle?
        opponent_unit.make_target_random(1).call.first.make_target
      end
    end
    return unless target_to_action

    @auto_action = true
    name = skill.name
    speed = @action_speed + skill.speed
    action_unit.add_action(self, target_to_action, skill, self.icon_index, icon_label, name, speed)
  end


  def update_action_by_state_restriction(action, state)
    action.states ||= []
    action.states << state
  end

  def reveal_skill(target, skill_id)
    # do nothing
  end

  def escape
    @escape_count += 1
    if status.escape_surely? || rand(100) < @escape_count * 25 + 5 + opponent_unit.escape_value
      friend_unit.escape
    end
  end

  # 装備の効果で自動で適用されるステートの処理
  def apply_auto_state(turn_count)
    return unless available?
    status.equipments.each_value do |item|
      next unless item
      apply_auto_state_item(turn_count, item)
    end
  end

  # 装備の効果で自動で適用されるステートのアイテムごとの処理
  def apply_auto_state_item(turn_count, item)
    return unless states = item.special_flag(:auto_state)
    states.each do |data|
      # データ型はDatabase::Table::Itemsで定義したもの
      next unless data[:turn] == turn_count
      status.add_state(data[:id])
    end
  end

  # 装備の効果で自動で適用されるステートの解除
  def remove_auto_state(item)
    return unless states = item.special_flag(:auto_state)
    states.each do |data|
      status.remove_state(data[:id])
    end
  end

  # 装備の効果で自動で使用されるスキルの処理
  def apply_auto_skill(turn_count)
    return unless available?
    db_skills = @manager.database.skills
    status.equipments.each_value do |item|
      next unless item
      next unless skills = item.special_flag(:auto_skill)
      skills.each do |data|
        # データ型はDatabase::Table::Itemsで定義したもの
        next unless data[:turn] == turn_count
        next unless s = db_skills[data[:id]]
        ts = self.make_target_by_skill(s)
        next unless ts = ts && ts.call
        ts.each do |t|
          manager.apply_action_effect(self, s, t)
        end
      end
    end
  end

  def on_unit_state_changed(old)
    case unit_state
    when Battle::Unit::State::COMMANDING
      @action_speed = Game::Agency.action_speed(status)
    when Battle::Unit::State::TURN_END
      echoed = status.in_state_with_special_flag?(:echo)
      status.ease_buffs
      status.ease_debuffs
      status.ease_states_due_to_timing(Itefu::Rgss3::Definition::State::AutoRemovalTiming::TURN) {|state, data|
        manager.push_repeat_skill_by_state(self, state, data)
      }
      status.remove_states_due_to_eased_out {|state|
        manager.push_chain_skill_by_state(self, state)
        true
      }
      if echoed
        manager.push_auto_skill(self, @skill_used_prev) if @skill_used_prev
      end
    when Battle::Unit::State::QUIT
      status.clear_all_buffs
      status.clear_all_debuffs
      status.remove_states_due_to_batttle_termination
      status.add_hp(1, false) if status.hp <= 0
    end
  end

  def memo_using_skill(action)
    if status.in_state_with_special_flag?(:echo)
      # 前のターンのスキル
      @skill_used_prev = @skill_used_current
    else
      @skill_used_prev = nil
    end
    # このターンのスキル
    if action && RPG::Skill === action.item
      @skill_used_current = action.item
    else
      @skill_used_current = nil
    end
  end

  def consume_mp_if_possible(cost)
    @party.consume_mp_if_possible(@actor_index, cost)
  end

  def play_damage_animation
    return unless available?

    anime = Animation::Damage.new(@scene_root.child(:sprite))
    manager.play_raw_animation(anime, anime)
  end

  def play_escaping_animation(disappear = false)
    return unless available?

    actor = @party.actor_data(@actor_index)
    if actor.special_flag(:escape) || disappear
      anime = Itefu::Animation::Battler.new(Itefu::Animation::Battler::EffectType::DISAPPEAR).auto_finalize
      anime.sprite = sprite_target
      manager.play_raw_animation(anime, anime)
    else
      anime = Animation::Escape.new(@scene_root.child(:sprite))
      manager.play_raw_animation(anime, anime)
    end
  end

  def play_winning_animation
    return unless available?

    anime = Animation::Winning.new(@scene_root.child(:sprite))
    manager.play_raw_animation(anime, anime)
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

  def replace_confusing_action(action_unit)
    skill_id = Integer(status.actor.special_flag(:uncontroll)) rescue 0
    guard_id = Integer(status.actor.special_flag(:awakened)) rescue 0

    db_skills = @manager.database.skills
    skill = db_skills[guard_id]

    action_unit.select_actions(self).each do |action|
      next unless item = action.item
      next unless RPG::Skill === item && item.id == skill_id
      # 混乱スキルを防御に差し替える
      action.item = skill
      action.label = skill.name
      action.action_name = skill.name
      action.target = self.make_target
    end
  end

private

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :value
    attr_observable :size
    attr_observable :color, :out_color
    attr_observable :damage_infos
    attr_observable :state_data

    def initialize(viewport)
      self.viewport = viewport
      self.value = ""
      self.size = 20
      self.color = Itefu::Color.Red
      self.out_color = Itefu::Color.Black
      self.damage_infos = []
      self.state_data = {}
    end
  end

end


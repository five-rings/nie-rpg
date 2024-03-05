=begin
=end
class Map::Unit::Ui::Shop < Map::Unit::Base
  def default_priority; end
  Operation = Itefu::Layout::Definition::Operation
  ITEM_ID_TO_BUY_SKILLS = 22
  MAX_PRICE_OF_ITEM = Definition::Game::MAX_MONEY

  def open?; @shop_data.nil?.!; end
  def traded_anything?; @traded_anything; end

  ShopData = Struct.new(:goods, :only_to_buy)

  def on_initialize(viewport, map_view)
    @message = Application.language.load_message(:map)
    @map_view = map_view

    if c = map_view.control(:shop_menu)
      @layouted = true
      @viewmodel = @@viewmodel
      initialize_controls
    else
      @viewmodel = ViewModel.new(map_view.viewport)
    end
  end

  def on_finalize
    finalize_controls if @layouted
    Application.language.release_message(:map)
  end

  def initialize_controls
    @map_view.control(:shop_menu).tap do |control|
      control.add_callback(:decided, method(:decided_menu))
      control.add_callback(:cursor_changed, method(:on_menu_changed))
      control.add_callback(:canceled, method(:canceled_menu))
    end
    @map_view.control(:shop_itemlist).tap do |control|
      control.add_callback(:cursor_changed, method(:cursor_itemlist_changed))
      control.add_callback(:decided, method(:decided_itemlist))
      control.add_callback(:canceled, method(:canceled_itemlist))
      control.cursor_decidable = method(:decidable_itemlist)
    end
    @map_view.control(:shop_numeric_dial).tap do |control|
      control.add_callback(:decided, method(:decided_dial))
      control.add_callback(:canceled, method(:canceled_dial))
    end
  end

  def finalize_controls
    @map_view.control(:shop_numeric_dial).tap do |control|
      control.remove_callback(:decided, method(:decided_dial))
      control.remove_callback(:canceled, method(:canceled_dial))
    end
    @map_view.control(:shop_itemlist).tap do |control|
      control.cursor_decidable = nil
      control.remove_callback(:cursor_changed, method(:cursor_itemlist_changed))
      control.remove_callback(:decided, method(:decided_itemlist))
      control.remove_callback(:canceled, method(:canceled_itemlist))
    end
    @map_view.control(:shop_menu).tap do |control|
      control.remove_callback(:decided, method(:decided_menu))
      control.remove_callback(:cursor_changed, method(:on_menu_changed))
      control.remove_callback(:canceled, method(:canceled_menu))
    end
  end

  def load_layout
    return if @layouted

    @@viewmodel = @viewmodel
    c = @map_view.add_layout(:map_root, "map/shop", @viewmodel)

    @layouted = true
    initialize_controls
  end

  def prepare(mode, location = nil)
    @special = mode && mode.intern
    @location = location && location + ":"
    case @special
    when :skill, :magic
      # スキル購入 = トークン消費
      @viewmodel.currency_unit = @message.text(:shop_coin_unit)
      @viewmodel.currency_icon = manager.database.items[ITEM_ID_TO_BUY_SKILLS].icon_index
    when :quest
      # 素材と報酬の物々交換
    else
      # 通常 = 所持金を消費
      @viewmodel.currency_unit = nil
      @viewmodel.currency_icon = nil
      @special = nil
    end
  end

  def open(goods, only_to_buy, type = :buy)
    load_layout
    @traded_anything = false
    @shop_data = ShopData.new(goods, only_to_buy)

    update_budget
    @map_view.play_animation(:shop_budget_window, :in)

    if only_to_buy
      update_goods(type)
      open_itemlist
    else
      update_itemlist(type)
      @map_view.control(:shop_menu).cursor_index = 0
      @map_view.play_animation(:shop_menu_window, :in).finisher {
        @map_view.push_focus(:shop_menu)
      }
      @map_view.play_animation(:shop_itemlist_window, :in)
    end

    Graphics.frame_reset
  end

  def open_to_sell_importants
    open([], true, :buy_important)
  end

  def update_goods(type)
    @trade_type = type
    @trade_mode = -1

    @goods = case type
      when :buy
        @trade_mode = 1
        db = manager.database
        items = db.items
        weapons = db.weapons
        armors = db.armors
        @shop_data.goods.map {|entry|
          item = case entry.item_type
                 when 0
                   items[entry.id]
                 when 1
                   weapons[entry.id]
                 when 2
                   armors[entry.id]
                 end
          if item
            price = entry.price || item.price
            price = nil if price >= MAX_PRICE_OF_ITEM
            nsr = false
            if quest_reward?(price) && quest_reward_unavailable?(item)
              price = nil
              disabled = true
            else
              if price && price < 0
                price = 0
                nsr = true
              end
              disabled = false
            end
            ItemData.new(item.icon_index, item.name, price, item, disabled).not_special_reward(nsr).special_color(item.special_flag(:shop_color))
          end
        }.tap {|a| a.compact! }
      when :buy_important
        @trade_mode = 1
        important = Map::SaveData::GameData.important
        important.items.keys.map! {|item|
          price = important.price_overridden(item) || price_to_buy_back(item)
          ItemData.new(item.icon_index, item.name, price, item)
        }.reverse!
      when :sell_material
        # 素材
        Map::SaveData::GameData.inventory.items.each_key.select {|item|
          item.special_flag(:material) && item.special_flag(:hidden).!
          # 素材は使用したりしないのでID順に並べる
        }.sort!.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }
      when :sell_tool
        # その他
        Map::SaveData::GameData.inventory.select_items {|item|
          item_to_use?(item).! && item.special_flag(:material).nil? && item.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      when :sell_usable
        # 使用可能な道具
        Map::SaveData::GameData.inventory.select_items {|item|
          item_to_use?(item) && item.consumable.! && item.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      when :sell_consumable
        # 消耗品
        Map::SaveData::GameData.inventory.select_items {|item|
          item_to_use?(item) && item.consumable && item.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      when :sell_weapon
        # 武器
        Map::SaveData::GameData.inventory.select_weapons {|weapon|
          weapon.special_flag(:material).nil? && weapon.wtype_id != 0 && weapon.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      when :sell_armor
        # 防具（アクセサリを除く)
        Map::SaveData::GameData.inventory.select_armors {|armor|
          armor.special_flag(:material).nil? &&
          armor.etype_id != Itefu::Rgss3::Definition::Equipment::Slot::ACCESSORY &&
          armor.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      when :sell_accessory
        # アクセサリ
        Map::SaveData::GameData.inventory.select_armors {|armor|
          armor.special_flag(:material).nil? &&
          armor.etype_id == Itefu::Rgss3::Definition::Equipment::Slot::ACCESSORY &&
          armor.special_flag(:hidden).!
        }.map! {|item|
          ItemData.new(item.icon_index, item.name, price_to_sell(item), item)
        }.reverse!
      end
  end

  def price_to_sell(item)
    price = price_to_sell_impl(item)
    price > 0 ? price : nil
  end

  def price_to_sell_impl(item)
    nts = @location && item.special_flag(:sell)
    price_data = nts && nts.split(",").find {|data| data.start_with?(@location) }
    if price = (Integer(price_data && price_data.split(":")[1]) rescue nil)
      # エリアごとの指定価格
      price
    else
      case item
      when RPG::EquipItem
        # 装備品は9割で下取り
        item.price * 9 / 10
      else
        # それ以外は半値
        item.price / 2
      end
    end
  end

  def price_to_buy_back(item)
    if price = price_to_sell(item)
      price + Itefu::Utility::Math.max(1, price / 10)
    else
      price = 1
    end
  end

  def quest_reward?(price)
    # 0: 交換可能なクエスト報酬
    # nil: 他の素材とでないと交換できない報酬
    @special == :quest && (price == 0 || price.nil?)
  end

  def quest_reward_unavailable?(item)
    return true if Map::SaveData::GameData.reward.received?(item)
    if num = item.special_flag(:amount)
      return num <= Map::SaveData::GameData.number_of_item(item)
    end
    false
  end

  # 今使用できる状態のアイテムか
  def item_usable?(item)
    RPG::UsableItem === item &&
    Itefu::Rgss3::Definition::Skill::Occasion.usable_in_fieldmenu?(item.occasion)
  end

  # 使用する用のアイテムか
  def item_to_use?(item)
    RPG::UsableItem === item &&
    Itefu::Rgss3::Definition::Skill::Occasion::UNUSABLE != item.occasion
  end

  def decided_menu(control, cursor_index, *args)
    c = control.child_at(cursor_index)
    update_goods(c && c.item)
    if @goods.nil? || @goods.empty?
      @viewmodel.notice = @message.text(:shop_sell_noitem)
      control.push_focus(:notice_message)
    else
      open_itemlist(control)
    end
  end
 
  def on_menu_changed(control, next_index, current_index)
    if next_index != current_index
      @map_view.control(:shop_itemlist).tap do |control|
        if control.cursor_index != 0
          control.cursor_index = 0
          control.scroll_to_child(0)
        end
      end
    end
    c = control.child_at(next_index)
    update_itemlist(c && c.item)
  end

  def update_itemlist(type)
    update_goods(type)
    @viewmodel.items = @goods
    update_price
  end

  def open_itemlist(control = nil)
    @viewmodel.items = @goods
    update_price
    update_description(@goods[0])
    # @map_view.control(:shop_itemlist).tap do |control|
    #   control.cursor_index = 0
    #   control.scroll_to_child(0)
    # end
    @map_view.play_animation(:shop_description_window, :in)
    unless control
      @map_view.play_animation(:shop_itemlist_window, :in)
    end
    (control || @map_view).push_focus(:shop_itemlist)
  end

  def canceled_menu(control, cursor_index)
    play_closing_animation(:shop_budget_window)
    play_closing_animation(:shop_menu_window)
    play_closing_animation(:shop_itemlist_window)
    @map_view.control(:shop_itemlist).cursor_index = 0
    @shop_data = nil
  end

  def play_closing_animation(control_id)
    if c = @map_view.control(control_id)
      opened = c.openness > 0
      if anime = c.animation_data(:in)
        opened = true if anime.playing?
        anime.finish
      end
      if anime = c.animation_data(:out)
        opened = false if anime.playing?
      end
      c.play_animation(:out) if opened
    end
  end

  def decidable_itemlist(control, index)
    c = control.child_at(index)
    return false unless item = c && c.item

    if @trade_mode > 0
      true
    else
      Map::SaveData::GameData.inventory.has_item?(item.item)
    end
  end

  def decided_itemlist(control, cursor_index, x, y)
    return unless decidable_itemlist(control, cursor_index)
    c = control.child_at(cursor_index)
    return unless item = c && c.item

    if @trade_mode > 0
      unless item.price.value
        case @special
        when :skill
          @viewmodel.notice = @message.text(:shop_learnt)
        when :quest
          # 術式は習得でなく販売なのでこちらになる
          case @trade_type
          when :buy
            if quest_reward_unavailable?(item.item)
              @viewmodel.notice = @message.text(:shop_rewarded)
            else
              @viewmodel.notice = @message.text(:shop_underqualified)
            end
          else
            @viewmodel.notice = @message.text(:shop_soldout)
          end
        else
          @viewmodel.notice = @message.text(:shop_soldout)
        end
        control.push_focus(:notice_message)
        return
      end

      case @special
      when :skill, :magic
        budget = Map::SaveData::GameData.inventory.number_of_item_by_id(ITEM_ID_TO_BUY_SKILLS)
      else
        budget = Map::SaveData::GameData.party.money
      end
      if budget < item.price.value
        case @special
        when :skill, :magic
          @viewmodel.notice = @message.text(:shop_nocoin)
        else
          @viewmodel.notice = @message.text(:shop_nomoney)
        end
        control.push_focus(:notice_message)
        return
      end
    else
      unless price_to_sell(item.item)
        @viewmodel.notice = @message.text(:shop_sell_worthless)
        control.push_focus(:notice_message)
        return
      end
    end

    @viewmodel.item = item
    case @trade_type
    when :buy
      if item.price.value == 0
        @viewmodel.item_max = 1
      else
        if num = item.item.special_flag(:amount)
          num -= Map::SaveData::GameData.number_of_item(item.item)
        end
        @viewmodel.item_max = Itefu::Utility::Math.clamp_with_nil(nil, num, budget / item.price.value)
      end
    when :buy_important
      @viewmodel.item_max = Map::SaveData::GameData.important.number_of_item(item.item)
    else
      @viewmodel.item_max = Map::SaveData::GameData.inventory.number_of_item(item.item)
    end

    @map_view.control(:shop_numeric_dial).number = @map_view.control(:shop_numeric_dial).min_number
    @map_view.play_animation(:shop_numeric_window, :in)
    control.push_focus(:shop_numeric_dial)
  end

  def canceled_itemlist(control, cursor_index)
    play_closing_animation(:shop_description_window)
    play_closing_animation(:shop_status_window)
    if @map_view.control(:shop_menu_window).openness == 0
      # ショップメニューを開いていないので戻らずに退店
      play_closing_animation(:shop_itemlist_window)
    end
    if @shop_data.only_to_buy
      play_closing_animation(:shop_budget_window)
      @shop_data = nil
      @map_view.control(:shop_itemlist).cursor_index = 0
    else
      # ここでカーソルなどをリセット
      # @map_view.control(:shop_itemlist).tap do |control|
      #   control.cursor_index = 0
      #   control.scroll_to_child(0)
      # end
    end
  end

  def cursor_itemlist_changed(control, next_index, current_index)
    if next_index
      item = @viewmodel.items[next_index]
      update_description(item)
    end
  end

  def decided_dial(control, cursor_index, x, y)
    item = @viewmodel.item.value
    num = control.unbox(control.number)
    inventory = Map::SaveData::GameData.inventory
    inventory.add_item(item.item, num * @trade_mode)
    inventory.replace_item(item.item, 1) if @trade_mode > 0

    case @special
    when :skill, :magic
      inventory.remove_item_by_id(ITEM_ID_TO_BUY_SKILLS, num)
    else
      Map::SaveData::GameData.party.add_money(-1 * item.price.value * num * @trade_mode)
      if quest_reward?(item.price.value) && item.reward_not_special.!
        Map::SaveData::GameData.reward.add_item(item.item)
      end
    end
    @traded_anything = true if num > 0

    update_budget
    update_possession(item)

    if @trade_mode < 0
      # 売ってしまっただいじなものを記録しておく
      if Game::Agency.important_item?(item.item)
        Map::SaveData::GameData.important.add_item(item.item, num)
      end

      # すべて売ってしまったものを一覧から除外
      @viewmodel.items.change(true) do |items|
        items.keep_if {|entry|
          inventory.has_item?(entry.item)
        }
      end
    elsif @trade_type == :buy_important
      # 買い戻しただいじなものを消す
      Map::SaveData::GameData.important.remove_priced_item(item.item, num)
      # 一覧から除外
      @viewmodel.items.change(true) do |items|
        items.keep_if {|entry|
          Map::SaveData::GameData.important.has_item?(entry.item)
        }
      end
    else
      if item.price.value == 0 && num > 0
        # @note 無料アイテムを購入する場合は何か一つ買ったら終わりにする
        @viewmodel.items.value.clear
      else
        update_price
      end
    end

    # close window
    play_closing_animation(:shop_numeric_window)
    @map_view.pop_focus

    if @viewmodel.items.value.empty?
      # close itemlist window
      play_closing_animation(:shop_description_window)
      play_closing_animation(:shop_status_window)
      if @map_view.control(:shop_menu_window).openness == 0
        # ショップメニューを開いていないので戻らずに退店
        play_closing_animation(:shop_itemlist_window)
      end
      if @shop_data.only_to_buy
        play_closing_animation(:shop_budget_window)
        @shop_data = nil
        @map_view.control(:shop_itemlist).cursor_index = 0
      end
      @map_view.pop_focus
    end
  end

  def canceled_dial(control, cursor_index)
    play_closing_animation(:shop_numeric_window)
  end

  def update_description(item = nil)
    if item
      @viewmodel.description = item.item.description
      if RPG::EquipItem === item.item &&
          (item.item.special_flag(:material).! ||  # 強化素材は装備しないのでキャラ情報は不要
           item.item.special_flag(:material) == 0) # 秘術はmaterialだがスキルなのでキャラ情報を表示したい
        actors = Map::SaveData::GameData.party.members.map {|actor_id|
          actor = Map::SaveData::GameData.actor(actor_id)
          actor && actor.able_to_equip?(item.item) && actor || nil
        }.compact
        @viewmodel.actors.modify actors
        @viewmodel.actors_for_status = actors

        # ステータス差分の設定
        pos = Definition::Game::Equipment.convert_from_rgss3(item.item.etype_id)
        @viewmodel.actors_for_status.value.each do |actor|
          params = {
            max_hp: actor.max_hp,
            max_mp: actor.max_mp,
            attack: actor.attack,
            defence: actor.defence,
            magic: actor.magic,
            footwork: actor.footwork,
            accuracy: actor.accuracy,
            evasion: actor.evasion,
            luck: actor.luck,
          }
          old = actor.equipment(pos)
          actor.no_auto_clamp do
            actor.equip(pos, item.item)
            params.each do |key, value|
              params[key] = actor.send(key) - value
            end
            actor.equip(pos, old)
          end
          if actor_param = @viewmodel.actor_params[actor.actor_id]
            params.each do |key, value|
              actor_param[key].modify value
            end
          else
            params.each do |key, value|
              params[key] = Itefu::Layout::ObservableObject.new(value)
            end
             @viewmodel.actor_params[actor.actor_id] = params
          end
        end
      else
        @viewmodel.actors = []
      end
      @viewmodel.item_to_compare = item.item
    else
      @viewmodel.description = ""
      @viewmodel.actors = []
      @viewmodel.item_to_compare = nil
    end

    # ステータス比較ウィンドウを必要に応じて開閉
    if c = @map_view.control(:shop_status_window)
      if @viewmodel.actors.value.empty?
        if c.openness > 0
          unless @anime_status_out && @anime_status_out.playing?
            @anime_status_out = c.play_animation(:out)
          end
        end
      elsif item && item.item.special_flag(:material).nil? && item.item.special_flag(:hidden).!
        if c.openness < 0xff
          unless @anime_status_in && @anime_status_in.playing?
            @anime_status_in = c.play_animation(:in)
          end
        end
      end
    end

    update_possession(item)
  end

  def update_possession(item = nil)
    if item
      @viewmodel.has_count = Map::SaveData::GameData.number_of_item(item.item, false)
    else
      @viewmodel.has_count = ""
    end
  end

  def update_budget
    case @special
    when :skill, :magic
      @viewmodel.budget = Map::SaveData::GameData.inventory.number_of_item_by_id(ITEM_ID_TO_BUY_SKILLS)
    else
      @viewmodel.budget = Map::SaveData::GameData.party.money
    end
  end

  def update_price
    return unless @trade_type == :buy
    @viewmodel.items.value.each do |item|
      next unless num = item.item.special_flag(:amount)
      if num <= Map::SaveData::GameData.number_of_item(item.item)
        item.price = nil
      end
    end
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :budget
    attr_observable :has_count, :description
    attr_observable :items
    attr_observable :item, :item_max
    attr_observable :item_to_compare
    attr_observable :notice
    attr_observable :actors, :actors_for_status
    attr_observable :currency_unit
    attr_observable :currency_icon
    attr_accessor :actor_params

    def initialize(viewport)
      self.viewport = viewport
      self.budget = 0
      self.has_count = nil
      self.description = ""
      self.items = []
      self.item = nil
      self.item_max = 0
      self.item_to_compare = nil
      self.notice = ""
      self.actors = []
      self.currency_unit = nil
      self.currency_icon = nil
      self.actors_for_status = []
      self.actor_params = {}
    end
  end

  class ItemData
    include Itefu::Layout::ViewModel
    attr_accessor :icon_index
    attr_accessor :name
    attr_observable :price
    attr_accessor :item
    attr_accessor :disabled
    attr_accessor :item_color
    attr_accessor :reward_not_special

    def initialize(icon_index, name, price, item, disabled = false)
      self.icon_index = icon_index
      self.name = name
      self.price = price
      self.item = item
      self.disabled = disabled
    end

    def not_special_reward(flag)
      self.reward_not_special = flag if flag
      self
    end

    def special_color(color)
      self.item_color = Itefu::Color.create(*color.split(",").map {|v| Integer(v) }) if color
      self
    rescue
      self
    end
  end

end

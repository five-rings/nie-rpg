=begin
  マップ用のEventInterpreter 
=end
class Event::Interpreter::Map
  include Event::Interpreter
  attr_accessor :map_manager
  attr_accessor :map_instance

  module Constant
    PRICE_REWARDED = 0
    PRICE_REWARDED_NOT_SPECIAL = -1
    PRICE_UNQUALIFIED = Definition::Game::MAX_MONEY
    EndingType = Definition::Game::EndingType
  end
  include Constant

  def manager; map_manager; end
  def database; map_manager.database; end
  def sound; map_manager.sound; end
  def common_message; map_manager.lang_common_events; end
  def event_text(id, *indices); text_from_message_with_id(map_instance.message, id, indices) || ""; end
  def map?; true; end

  def initialize(parent = nil)
    super
    if parent
      @map_manager = parent.map_manager
      @map_instance = parent.map_instance
    end
  end

  def event_wait(count = 1)
    if count >= 1
      @event_status.data[:wait] ||= 0
      @event_status.data[:wait] += count
    end
    super
  end
  

  # --------------------------------------------------
  # 独自実装

  # 特殊コマンド
  def command_sound(*args); end
  # アイコン表示用
  def command_talk(*args); end
  def command_find(*args); end
  def command_icon(*args); end
  def command_shop(*args); end
  def command_curio(*args); end
  def command_warp(*args); end
  def command_skill(*args); end
  def command_magic(*args); end
  def command_quest(*args); end
  def command_talk!(*args); command_check_event; end
  def command_find!(*args); command_check_event; end
  def command_icon!(*args); command_check_event; end
  def command_shop!(*args); command_check_event; end

  # イベント（ページ単位）をチェック済みにする
  def command_check_event(bit = nil)
    if bit
      # 指定したフラグが立っていたらチェック済みにする
      bit = Integer(bit)
      return unless SaveData.collection.event_flag_checked?(event_status.map_id, event_status.event_id, event_status.page_index, bit)
    end
    # このイベントが存在しているマップを基準に考えるのでcurrent_map_id（マップ移動で変化する）ではなくmap_id
    SaveData.collection.check_event(event_status.map_id, event_status.event_id, event_status.page_index)
  rescue
    ITEFU_DEBUG_OUTPUT_ERROR "can't convert #{bit} into Integer"
    ITEFU_DEBUG_DUMP_EVENT_INFO
  end

  # イベント（ページ単位）はチェック済みか
  def event_checked?
    SaveData.collection.event_checked?(event_status.map_id, event_status.event_id, event_status.page_index)
  end

  # イベントページを部分的にチェックする（フラグを立てる）
  def command_check_event_flag(digit)
    digit = Integer(digit)
    ITEFU_DEBUG_ASSERT(digit >= 1, "digit(#{digit}) must be >= 1")
    SaveData.collection.check_event_flag(event_status.map_id, event_status.event_id, event_status.page_index, 1 << (digit - 1))
  rescue
    ITEFU_DEBUG_OUTPUT_ERROR "can't convert #{digit} into Integer"
    ITEFU_DEBUG_DUMP_EVENT_INFO
  end

  # BGSの音量をフェードする
  def command_bgs_fade(volume, *args)
    sound.fade_bgs_volume(Integer(volume))
  end

  # オートセーブ
  def command_autosave(*args)
    unless @event_status.data[:autosaved]
      @event_status.data[:autosaved] = true
      SaveData.save_map(map_manager)
      SaveData.save_game
    end
    @event_status.data[:autosaved] = false

    if @to_backup
      SaveData.duplicate_game_data
      @to_backup = false
      map_manager.push_notice(:backup_created)
    end
  end

  # 次のオートセーブ時にバックアップを作成するようにする
  def command_to_backup(*args)
    @to_backup = true
  end

  # クイックセーブ枠にセーブ
  def command_quicksave(*args)
    unless @event_status.data[:autosaved]
      @event_status.data[:autosaved] = true
      map_manager.quick_save
    end
    @event_status.data[:autosaved] = false
  end

  # エピソードを公開
  def command_episode(key, *args)
    sym_key = key.intern
    map_manager.push_notice(:"episode_#{key}") unless episode_open?(sym_key)
#ifdef :ITEFU_DEVELOP
    if :all == sym_key
      SaveData.collection.open_all_episodes
    else
#endif
      SaveData.collection.open_episode(sym_key)
#ifdef :ITEFU_DEVELOP
    end
#endif
  end
  def event_wait_episode; end

  # 自動スクロールを現在の場所までに制限
  def command_limit_scrolling(*args)
    t, b, l, r = nil
    args.each do |v|
      case v[0]
      when "t"
        t = true
      when "b"
        b = true
      when "l"
        l = true
      when "r"
        r = true
      end
    end
    map_manager.scroll_unit.limit_center(t, b, l, r)
  end
  def event_limit_scrolling; end

  # スクロール位置を強制的に移動
  def command_scroll_immediately(x = nil, y = nil, *args)
    x = Integer(x) rescue nil if x
    y = Integer(y) rescue nil if y
    map_manager.scroll_unit.scroll(x, y)
  end

  # ギミックを設定する
  def command_gimmick(type, *args)
    map_manager.gimmick_unit.change_additional_gimmick(type, *args)
  end

  # BGMを固定する
  def command_lock_bgm(value = true, *args)
    value = case value
            when "false","0","nil"
              false
            else
              true
            end
    map_manager.lock_bgm(value)
  end

  # ジョブ名を変更
  def command_change_job_name(actor_id, name = nil, *args)
    actor = actor_instance(Integer(actor_id))
    ITEFU_DEBUG_ASSERT(actor.nil?.!, "actor id #{actor_id} is not exist, intended to change job name to: #{name}")
    begin
      actor.change_job_name(Integer(name))
    rescue ArgumentError
      actor.change_job_name(name)
    end
  end

  # スキルを習得テーブルに追加
  def command_add_learning(actor_id, skill_id, level = nil)
    actor_id = Integer(actor_id)
    skill_id = Integer(skill_id)
    level = Integer(level) if level
    actor = actor_instance(actor_id)
    actor.add_skill_to_learnings(skill_id, level)
  end

  # 捨てたアイテムを捧げ物にする
  # @note 条件分岐のスクリプトから呼ぶと、自動で解除される
  def discard_as_offering(conclude = false)
    if conclude
      @discard_as_offering = nil
    else
      @discard_as_offering = current_command.indent
    end
  end

  # アイテムの追加を大事な物ショップに対して行う
  # @note 条件分岐のスクリプトから呼ぶと、自動で解除される
  def deal_with_important_shop(conclude = false)
    if conclude
      @important = nil
    else
      @important = current_command.indent
    end
    true
  end

  # 条件分岐の末尾で自動解除する
  def command_412(indent, *args)
    if @important == indent
      deal_with_important_shop(true)
    end
    if @discard_as_offering == indent
      discard_as_offering(true)
    end
    super
  end

  def event_add_item(item_id, diff)
    if @important
      # 大事な物ショップとの取引
      SaveData.important.add_item(database.items[item_id], diff)
    else
      super
      # 捧げ物にする処理を呼ぶようにする
      event_add_item_as_offering(database.items[item_id], diff)
    end
  end

  def event_add_item_to_inventory(item, diff, strip = false)
    if @important
      # 大事な物ショップとの取引
      SaveData.important.add_item(item, diff)
    else
      super
      # 捧げ物にする処理を呼ぶようにする
      event_add_item_as_offering(item, diff)
    end
  end

  # 捧げ物にする処理の実装
  def event_add_item_as_offering(item, diff)
    if @discard_as_offering && diff < 0
      SystemData.offering.add_item(item, -diff)
    end
  end

  # 捧げ物をリセットする
  def command_clear_benefit
    SystemData.offering.items.clear
  end

  # 捧げ物をアイテムとして取得する
  def command_receive_benefit
    SystemData.offering.items.each do |entry, count|
      case entry.kind
      when :item
        SaveData.inventory.add_item_by_id(entry.id, count)
      when :weapon
        SaveData.inventory.add_weapon_by_id(entry.id, count)
      when :armor
        SaveData.inventory.add_armor_by_id(entry.id, count)
      end
    end
    command_clear_benefit
  end

  # 変数操作を外部から切り分け局所化する
  def command_variable_localize(prefix = nil)
    @event_status.data[:variable_prefix] = prefix
  end

  # システムデータに保存するフラグ操作
  def command_system_flag(flag, value = true, *args)
    case value
    when String
      SystemData.flags[flag.intern] = eval(value)
    else
      SystemData.flags[flag.intern] = value
    end
  end

  # システムデータに保存するフラグの取得
  def system_flag(flag)
    case flag
    when String
      SystemData.flags[flag.intern]
    else
      SystemData.flags[flag]
    end
  end

  # 特殊なショップ
  def command_open_shop(type = nil, *args)
    shop_unit = map_manager.ui_unit.shop_unit
    shop_unit.prepare(@event_status.data[:shop_mode])

    case type
    when "important"
      # 大事なものショップ
      event_wait until event_message_closed?
      shop_unit.open_to_sell_importants
      branch(current_command.indent, shop_unit.traded_anything?)

      event_wait while shop_unit.open?

    else
      # コマンドで積んだ商品を売る
      if (goods = @event_status.data[:goods]) && goods.empty?.!
        # data[:goods]はevent_open_shopでも処理されるのでそちらに任せて空のgoodsを渡す
        event_open_shop(nil, true)
        event_wait while event_begin_in_shop?
      end
    end
  end

  # ショップで何で買い物するかなどを変える
  def command_shop_mode(mode = nil, *args)
    @event_status.data[:shop_mode] = mode
  end

  # ショップの区別
  def command_shop_location(loc = nil, *args)
    @event_status.data[:shop_location] = loc
  end

  # ショップの金額を変数IDとして扱う
  def command_price_as_variable(value = true, *args)
    value = case value
            when "false","0","nil"
              false
            else
              true
            end
    @event_status.data[:price_as_variable] = value
  end

  # 強化スロットあたりの装着数を増やす
  def command_upgrade_slot_capacity(*args)
    SaveData.system.max_embed_weapon += 1
  end

  # 武器の強化スロット数を増やす
  def command_upgrade_attack_slot(*args)
    SaveData.system.slot_of_weapon += 1
  end

  # 術式の強化スロット数を増やす
  def command_upgrade_magic_slot(*args)
    SaveData.system.slot_of_armor += 1
  end
  alias :command_upgrade_magick_slot :command_upgrade_magic_slot

  # 不思議な巻物／冊子のレベルを上げる
  def command_upgrade_magic_scroll
    SaveData.system.magic_scroll_level ||= 0
    SaveData.system.magic_scroll_level += 1
    count = SaveData.system.magic_scroll_level
    repo = SaveData.repository

    # 不思議な巻物／冊子を隠し強化する
    item = database.armors[8]   # @magic: 不思議な輝石
    database.armors.each do |base_item|
      next unless base_item && base_item.special_flag(:magicscroll)
      base_item.assign_extra_item(item, count)
      # 強化内容をセーブデータに保存する
      repo.add_item(base_item) unless repo.has_item?(base_item)
    end
    # 装備している場合パラメータが変わるかもしれないので
    iterate_actors(0, nil) do |actor|
      actor.clamp_hp_mp
    end
  end

  # 合成画面へ遷移
  def command_open_synth(*args)
    event_wait until event_message_closed?
    map_manager.quit(::Map::ExitCode::OPEN_SYNTH)
  end

  # 新規にゲームを始める
  def command_new_game(*args)
    event_wait until event_message_closed?

    # 新規にゲームを開始する
    # SaveData.reset
    # map_manager.quit(::Map::ExitCode::NEW_GAME)

    # ロード画面を開く
    map_manager.quit(::Map::ExitCode::OPEN_SAVE, :new_game)
  end

  # 女神帰還を禁止するかを切り替える
  def command_goddess_prohibit(value = true, *args)
    value = case value
            when "false","0","nil"
              false
            else
              true
            end
    SaveData.system.to_go_home = value.!
  end

  # 精霊ダンジョンで配置をランダムにする
  def command_place_symbols_randomly(rate_treasure = 100, rate_chiritori = 100, rate_chiritori_parade = 50)
    # プレイヤー
    r = []
    map_instance.region_tiles(61) {|cell_x, cell_y| # @magic region id of the player
      if map_instance.passable_tile?(cell_x, cell_y, Itefu::Rgss3::Definition::Direction::NOP)
        r << [cell_x, cell_y]
      end
    }
    if r = r.sample
      event_move_player(current_map_id, r[0], r[1], Itefu::Rgss3::Definition::Direction::NOP, Itefu::Fade::Manager::FadeType::TRANSITION)
    end
    # 妖精のかくし道
    r = map_instance.region_tiles(62) # @magic region id of the moving point
    if r = r.sample
      map_instance.event_units.each {|event|
        next unless event.enabled? && event.event.name.end_with?("!")
        event_move_event(event, r[0], r[1], Itefu::Rgss3::Definition::Direction::NOP)
      }
    end
    # 敵や宝箱
    enable = event_rand(100) < (Integer(rate_treasure) rescue 100)
    place_symbols_to_region(enable, 63, "@63") # @magic region id of enemies
    # ちりとりネズミ
    if event_rand(100) < (Integer(rate_chiritori) rescue 100)
      enable =  event_rand(100) < (Integer(rate_chiritori_parade) rescue 0)
      # ちりとりネズミの群れ
      if enable
        # リージョン50-59から無作為に選ぶ
        tile_ids = (50..59).to_a.select {|id| map_instance.regioned_tile?(id) }
        tile_id = tile_ids.sample
        enable = false unless tile_id
      end
      place_symbols_to_region(enable, tile_id, "@50-59")
      # ちりとりネズミ
      place_symbols_to_region(enable.!, 60, "@60") # @magic region id of mice
    else
      # 非表示にする
      # ちりとりネズミ
      place_symbols_to_region(false, 60, "@60") # @magic region id of mice
      # ちりとりネズミの群れ
      place_symbols_to_region(false, tile_id, "@50-59")
    end
  end

  def place_symbols_to_region(enable, tile_id, event_suffix)
    if enable && r = map_instance.region_tiles(tile_id)
      r.shuffle!
      map_instance.event_units.each do |event|
        next unless event.enabled? && event.event.name.end_with?(event_suffix)
        if r.empty?
          # 配置場所がないので非表示にする
          event.disable
        else
          # ランダムに配置する
          p = r.pop
          event_move_event(event, p[0], p[1], Itefu::Rgss3::Definition::Direction::NOP)
        end
      end
    else
      # 非表示にする
      map_instance.event_units.each do |event|
        next unless event.enabled? && event.event.name.end_with?(event_suffix)
        event.disable
      end
    end
  end

  # 精霊ダンジョンの敵の数を数える
  def count_placing_enemies
    map_instance.event_units.count {|event|
      event.enabled? && event.event.name.end_with?("@")
    }
  end

  # ショップに並べるアイテムを指定する
  # @note EventShopItemのパラメータを指定する
  # @param [String] price 価格（evalされる）
  def command_push_goods(type_id, item_id, price = nil)
    @event_status.data[:goods] ||= []
    data = @event_status.data[:goods]
    data << EventShopItem.new(Integer(type_id), Integer(item_id), price && self.instance_eval(price))
  end

  # 選択肢を初期化する
  def initialize_choice_data
    @event_status.data[:choice] ||= {
      labels: [],
      keys: [],
      default: nil,
    }
  end

  # 選択肢を追加する
  def command_push_choice(key, choice, default = false, *args)
    data = initialize_choice_data
    data[:default] = data[:keys].size if default
    data[:keys] << (Integer(key) rescue key)
    data[:labels] << choice
  end
  def event_wait_push_choice; end

  def command_inherit_choices
    if @parent
      if pdata = @parent.event_status.data[:choice]
        data = initialize_choice_data
        data[:default] = pdata[:default] + data[:keys].size if pdata[:default]
        data[:keys].concat(pdata[:keys])
        data[:labels].concat(pdata[:labels])

        pdata[:labels].clear
        pdata[:keys].clear
        pdata[:default] = nil
      end
    else
      ITEFU_DEBUG_OUTPUT_WARNING ":inherit_choices is specified but it has no parent event"
    end
  end
  def event_wait_inherit_choices; end

  # 選択肢のデフォルトカーソル位置を設定する
  # @note nilで前回の位置を維持
  def command_choice_index(index = nil)
    index = Integer(index) if index
    map_manager.ui_unit.message_unit.choice_index_to_reset = index
  end

  # 追加された選択肢を表示する
  def command_show_choice(*args)
    data = @event_status.data[:choice]
    if data && extra_choices?
      if common_event?
        msg = common_message
      else
        msg = map_instance.message
      end
      keys = data[:keys]
      data[:labels].map!.with_index {|label, i|
        message_text(msg, label) || label
      }
      event_show_choices(data[:labels], data[:default] || -1, false)
      event_wait while event_choices_showing?
      indent = current_command.indent
      branch(indent, data[:keys][branch_result(indent)])
      data[:labels].clear
      data[:keys].clear
      data[:default] = nil
    end
  end
  def event_wait_show_choice; end

  def extra_choices?
    data = @event_status.data[:choice]
    labels = data && data[:labels]
    labels && labels.empty?.!
  end

  # @return [Boolean] 買戻し可能なだいじなものがあるか
  def selling_important_items?
    SaveData.important.items.empty?.!
  end

  # @return [Boolean] ダッシュ中か
  def dashing?
    player_object.dashing?
  end

  # @return [Boolean] スニーク中か
  def sneaking?
    player_object.sneaking?
  end

  # @return [Boolean] キャラ移動中か
  def moving?
    player_object.moving?
  end

  # @return [Boolean] ニエが会話に反応するか
  def nie_speaking?
#ifdef :ITEFU_DEVELOP
    if Input.pressing?(::Input::LEFT)
      true
    elsif Input.pressing?(::Input::RIGHT)
      false
    else
#endif
    @@nie_speaking ||= rand(2)
    @@nie_speaking = Itefu::Utility::Math.loop(0, 1, @@nie_speaking + 1) if rand(10) != 0
    party_member?(2) && # @magic: Nie's actor id
    @@nie_speaking == 0
#ifdef :ITEFU_DEVELOP
    end
#endif
  end

  # @return [Itefu::Rgss3::Definition::Direction] ニエの向きを返す
  def nie_direction
    if follower = player_object.find_follower(2) # @magic: ニエ
      follower.direction
    else
      Itefu::Rgss3::Definition::Direction::NOP
    end
  end

  # @return [Boolean] 指定したエピソードが公開されているか
  def episode_open?(key)
    SaveData.collection.episode_open?(key)
  end

  # ガイドを強制的に開く
  def open_guide(all_hint = true)
    map_manager.ui_unit.open_guide(all_hint)
  end

  # クエスト素材アイテムを渡す
  def give_quest_token(item_id)
    SaveData.reward.exchange(item_id)
    event_add_item(item_id, -1)
  end

  # 交換したことのあるクエスト素材か
  def quest_token_given?(item_id)
    SaveData.reward.exchanged?(item_id)
  end

  # 女神帰還の帰還先が未指定の場合初期位置を設定する
  def initialize_goddess_home(map_id, cell_x, cell_y, direction, name)
    unless SaveData.collection.home_place_registered?
      map_id ||= current_map_id
      cell_x ||= subject.cell_x
      cell_y ||= subject.cell_y
      direction ||= subject.direction
      name ||= map_instance.map_data.display_name
      SaveData.collection.register_home_place(map_id, cell_x, cell_y, direction, name)
    end
  end

  # 現在の場所を最後に訪れた拠点として登録する
  def visit_goddess_home
    subject = player_object
    SaveData.collection.register_home_place(current_map_id, subject.cell_x, subject.cell_y, subject.direction, map_instance.map_data.display_name)
  end

  # 拠点に帰還できるか
  def goddess_home?
    SaveData.system.to_go_home && SaveData.collection.home_place_registered?
  end

  # 帰還先のマップ名
  def map_name_of_goddess_home
    name = SaveData.collection.name_of_home_place
    if name.nil? || name.empty?
      msg = map_manager.lang_message
      msg && msg.text(:unknown_home_point) || ""
    else
      name
    end
  end

  # 拠点に帰還する
  def return_to_goddess_home
    return unless data = SaveData.collection.home_place
    event_move_player(
      data[:map_id],
      data[:x], data[:y],
      data[:d],
      Itefu::Rgss3::Definition::Event::FadeType::NONE
    )
    event_wait while event_player_moving?
  end

  # 現在の場所を帰還場所として登録する
  def visit_fairy_home(map_id = nil)
    subject = player_object
    pos = SaveData.collection.add_home_point(map_id || fairy_map_id, subject.cell_x, subject.cell_y, subject.direction, map_instance.map_data.display_name)
    SaveData.collection.register_home_point(pos)
  end

  # @return [Boolean] 帰還できる場所があるか
  def fairy_home?
    return false unless hp = fairy_home_point
    # あまりに近い場合は飛べなくする
    return true if hp[:map_id] != current_map_id
    subject = player_object
    (subject.cell_x - hp[:x]).abs + (subject.cell_y - hp[:y]).abs > 1
  end

  # 妖精帰還での帰還先のマップ名
  def map_name_of_fairy_home
    name = SaveData.collection.name_of_home_place(fairy_home_point)
    if name.nil? || name.empty?
      msg = map_manager.lang_message
      msg && msg.text(:unknown_home_point) || ""
    else
      name
    end
  end

  # 妖精帰還で参照するマップID
  def fairy_map_id
    map_instance.fairy_map_id || current_map_id
  end

  # 妖精帰還する帰還先
  def fairy_home_point
    if SaveData.system.to_go_home
      # 通常時は最後にアクセスした妖精の集いへ帰れる
      SaveData.collection.home_point
    else
      # 帰還アイテム禁止区域でも、同一マップの妖精の集いへの帰還はできる
      subject = player_object
      SaveData.collection.home_point_nearest(fairy_map_id, subject.cell_x, subject.cell_y)
    end
  end

  # 帰還場所に移動する
  def move_to_fairy_home
    return unless point = fairy_home_point
    event_move_player(
      point[:map_id],
      point[:x], point[:y],
      point[:d] || Itefu::Rgss3::Definition::Direction::DOWN,
      Itefu::Rgss3::Definition::Event::FadeType::NONE
    )
    event_wait while event_player_moving?
  end

  # ランダムエンカウントでエンカウントする敵グループIDをランダムに取得
  def pick_troop_id_from_encounter_list
    subject = player_object
    if index = map_instance.pick_troop_index_from_encounter_list(subject.cell_x, subject.cell_y)
      map_instance.map_data.encounter_list[index].troop_id
    else
      0
    end
  end

  # 指定したオブジェクト間にパスが通っているか
  # @return [Boolean]
  # @param [Fixnum] from 始点のマップオブジェクトのID
  # @param [Fixnum] to 終点のマップオブジェクトのID
  # @param [Fixnum|NilClass] depth 探索する深さ
  def path_found_by_los?(from, to, depth = nil)
    from = mapobject(from)
    to = mapobject(to)
    path = map_instance.find_path_by_los2(from.cell_x, from.cell_y, to.cell_x, to.cell_y, depth)
    path.unreachable?.!
  end


  # --------------------------------------------------
  # アプリケーションで実装する必要のある補助機能
  
  def player_object
    map_manager.player_unit
  end

  def event_object(id)
    map_instance.event(id)
  end
  
  def mapobject_cell_x(subject)
    subject.cell_x
  end

  def mapobject_cell_y(subject)
    subject.cell_y
  end

  def mapobject_direction(subject)
    subject.direction
  end

  def mapobject_screen_x(subject)
    subject.screen_x
  end

  def mapobject_screen_y(subject)
    subject.screen_y
  end

  def terrain_tag_at_cell(cell_x, cell_y)
    map_instance.terrain_tag(cell_x, cell_y)
  end

  def event_id_at_cell(cell_x, cell_y)
    event = map_instance.find_event_mapobject(cell_x, cell_y, &:enabled?)
    event && event.id || 0
  end

  def tile_id_at_cell(cell_x, cell_y, layer_index)
    map_instance.tile_id(cell_x, cell_y, layer_index)
  end

  def region_id_at_cell(cell_x, cell_y)
    map_instance.region_id(cell_x, cell_y)
  end

  def variable(id)
    if prefix = @event_status.data[:variable_prefix]
      super("#{prefix}-#{id}")
    else
      super
    end
  end

  def change_variable(id, value)
    if prefix = @event_status.data[:variable_prefix]
      super("#{prefix}-#{id}", value)
    else
      super
    end
  end

  def common_event_finished(child, child_status)
    super
    if child_status
      event_status.data[:message] = true if child_status.data[:message]
    end
  end

  # --------------------------------------------------
  # アプリケーションで実装する必要のあるイベントの処理
  
  def event_show_message(message, face_name, face_index, background, position)
    if common_event?
      msg = common_message
    else
      msg = map_instance.message
    end

    if m = message_text(msg, message)
      message = m
    end

    message_unit = map_manager.ui_unit.message_unit
    message_unit.show(message, face_name, face_index, background, position)
    event_status.data[:message] = true # メッセージを表示したフラグ

    event_wait until message_unit.ready?
  end

  def event_message_showing?
    map_manager.ui_unit.message_unit.showing?
  end
  
  def event_message_closed?
    map_manager.ui_unit.message_unit.window_closed?
  end
  
  def event_wait_101
    command = current_command
    background = command.parameters[2]
    position = command.parameters[3]
    # 前のメッセージが既に表示されていて、可能なら上書きする
    # 上書きできない場合は一旦閉じてから新しいメッセージを表示する
    event_wait until event_message_closed? ||
                     map_manager.ui_unit.message_unit.reassignable?(background, position)
  end

  def event_show_choices(choices, cancel_value, to_replace = true)
    if common_event?
      msg = common_message
    else
      msg = map_instance.message
    end
    if to_replace
      choices.map!.with_index {|choice, i|
        message_text(msg, choice) || choice
      }
    end
    map_manager.ui_unit.message_unit.open_choices(choices, cancel_value) {|index|
      branch(current_command.indent, index)
    }
  end

  def event_choices_showing?
    map_manager.ui_unit.message_unit.choices_showing?
  end

  def event_show_numeric_input(variable_id, digit)
    map_manager.ui_unit.message_unit.open_numeric_input(digit) {|value|
     change_variable(variable_id, value)
    }
  end

  def event_numeric_input_showing?
    map_manager.ui_unit.message_unit.numeric_input_showing?
  end

  def event_show_item_select(variable_id)
    event_wait until event_message_closed?

    result = map_manager.result
    if ::RPG::BaseItem === result
      map_manager.clear_result
      if result.id != 0
        change_variable(variable_id, result)
      else
        change_variable(variable_id, nil)
      end
    else
      map_manager.quit(::Map::ExitCode::SELECT_ITEM)
      # 画面遷移できるよう処理を返す
      Fiber.yield
    end
  end

  # スクロール文章を表示する
  # @param [String] text 表示する文章
  # @param [Fixnum] speed スクロールする速さ [0-8]
  # @param [Boolean] not_to_fast_feed 早送り無効
  def event_show_scrolling_text(text, speed, not_to_fast_feed)
    raise Itefu::Exception::NotSupported
  end

  # @return [Boolean] スクロール文章を表示中か
  def event_scrolling_text_showing?; false; end

  def event_move_player(map_id, cell_x, cell_y, direction, fade_type)
    event_wait while player_object.moving?
    map_manager.transfer(map_id, cell_x, cell_y, direction, fade_type)
    if map_id != current_map_id
      @event_status.data[:map_id] = map_id
      # マップ移動が終わるまでは新しいマップは用意できていないのでmap_instanceは後で設定する
      @map_instance = nil
    end
  end

  # マップ移動後にmap_instanceを再設定する
  def command_201(indent, params)
    super
    @map_instance = map_manager.find_instance(current_map_id) if @map_instance.nil?
  end

  def event_player_moving?
    map_manager.transfering?
  end

  def event_move_vehicle(vehicle_type, map_id, cell_x, cell_y)
    raise Itefu::Exception::NotSupported
  end

  def event_vehicle_moving?(vehicle_type)
    raise Itefu::Exception::NotSupported
  end

  def event_move_event(subject, cell_x, cell_y, direction)
    subject.transfer_to_cell(cell_x, cell_y, true)
    subject.turn(direction)
  end

  def event_swap_event(subject, object, direction)
    cx = subject.cell_x
    cy = subject.cell_y
    subject.transfer_to_cell(object.cell_x, object.cell_y, true)
    object.transfer_to_cell(cx, cy, true)
    subject.turn(direction)
  end

  def event_event_moving?(subject)
    subject.moving?
  end

  def event_scroll(direction, distance, speed)
    map_manager.scroll_unit.start_event_scroll(direction, distance, speed)
  end

  def event_scrolling?
    map_manager.scroll_unit.scrolling?
  end

  def event_assign_route(subject, route, object)
    unless branch_result(BRANCH_TEMP)
      subject.add_route(route, object)
      branch(BRANCH_TEMP, true) if route.wait
    end
  end

  def event_routing?(subject)
    if (r = subject.routes[-1]) && r.finished?.!
      true
    else
      branch(BRANCH_TEMP, nil)
      false
    end
  end
  
  def event_get_vehicle_on_off
    raise Itefu::Exception::NotSupported
  end

  def event_change_transparency(transparent)
    player_object.transparent = transparent
  end

  def event_play_effect_animation(subject, anime_id)
    anime_data = database.animations[anime_id]
    @anime = Itefu::Animation::Effect.new(anime_data).auto_finalize
    @anime.offset_z(Itefu::Tilemap::Definition::Z_OVER_CHARACTERS)
    @anime.assign_target(subject.target_sprite, map_instance.map_viewport)
    map_manager.play_animation(@anime.object_id, @anime)
  end

  def event_effect_animation_playing?(subject)
    @anime && @anime.playing?
  end

  def event_show_balloon(subject, balloon_id)
    subject.start_balloon(balloon_id - 1, false)
  end

  def event_balloon_showing?(subject)
    subject.balloon_showing?
  end

  def event_disable_this_event
    if event_status.event_id
      event = map_instance.event(event_status.event_id)
      if event
        event.disable
      else
        ITEFU_DEBUG_OUTPUT_CAUTION "event_disable_this_event: no event found" 
        ITEFU_DEBUG_DUMP_EVENT_INFO
      end
    else
      ITEFU_DEBUG_OUTPUT_CAUTION "event_disable_this_event: no event_id specified"
      ITEFU_DEBUG_DUMP_EVENT_INFO
    end
  end

  def event_change_if_show_followers(to_show)
    player_object.show_followers(to_show)
  end

  def event_gather_followers
    player_object.gather_followers
  end
  
  def event_gathering_followers?
    player_object.gathering_followers?
  end

  def event_change_tone(tone, duration)
    map_manager.gimmick_unit.change_tone(tone, duration)
  end

  def event_flash(color, duration)
    map_manager.gimmick_unit.flash(color, duration)
  end

  def event_shake(power, speed, duration)
    map_manager.gimmick_unit.shake(power, speed, duration)
  end

  def event_show_picture(index, name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
    map_manager.picture_unit.show(index, name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
  end
  
  def event_move_picture(index, origin, x, y, zoom_x, zoom_y, opacity, blend_type, duration)
    map_manager.picture_unit.move(index, origin, x, y, zoom_x, zoom_y, opacity, blend_type, duration)
  end
  
  def event_rotate_picture(index, angle)
    map_manager.picture_unit.rotate(index, angle)
  end
  
  def event_change_picture_tone(index, tone, duration)
    map_manager.picture_unit.change_tone(index, tone, duration)
  end
  
  def event_erase_picture(index)
    map_manager.picture_unit.erase(index)
  end

  def event_change_weather(weather_type, power, duration, *args)
    map_manager.gimmick_unit.change_weather(weather_type, power, duration, *args)
  end


  def event_change_tileset(tileset_id)
    map_instance.change_tileset(tileset_id)
  end

  def event_change_parallax(name, loop_x, loop_y, sx, sy)
    map_instance.change_parallax(name, loop_x, loop_y, sx, sy)
  end

  def event_start_battle(troop_id, escape, lose)
    event_wait until event_message_closed?
    troop_id ||= pick_troop_id_from_encounter_list
    unless troop_id > 0
      ITEFU_DEBUG_OUTPUT_WARNING "Battle is ignored because troop_id(#{troop_id}) is invalid"
      return
    end

    result = map_manager.result
    if ::Battle::Result === result
      map_manager.clear_result
      # 戦闘結果で分岐する場合は勝敗を設定する
      if lose.! && result.outcome == Itefu::Rgss3::Definition::Event::Battle::Result::LOSE
        # 負けてはいけない戦いで負けた
        event_game_over(EndingType::GAME_OVER)
      elsif escape || lose
        branch(current_command.indent, result.outcome) 
      end
    else
      map_manager.quit_by_starting_battle(troop_id, escape, lose)
      # 画面遷移できるよう処理を返す
      Fiber.yield
    end
  end
  
  def event_being_in_battle?; false; end

  def event_open_shop(goods, only_to_buy)
    price_as_variable = @event_status.data[:price_as_variable]
    if @important
      # 大事な物ショップの在庫に追加する
      dbs = [
        database.items,
        database.weapons,
        database.armors,
      ]
      goods.each do |item|
        if db = dbs[item.item_type]
          SaveData.important.add_item_with_price(db[item.id], price_as_variable ? variable(item.price) : item.price)
        end
      end
    else
      # ショップを開く
      event_wait # イベント起動時の決定を受け付けないようにするため
      event_wait until event_message_closed?

      shop_unit = map_manager.ui_unit.shop_unit
      shop_unit.prepare(@event_status.data[:shop_mode], @event_status.data[:shop_location])

      if price_as_variable
        goods.each do |item|
          item.price = variable(item.price)
        end
      end
      if data = @event_status.data[:goods]
        if goods && goods.equal?(data).!
          goods.concat data
        else
          goods = data
        end
      end
      shop_unit.open(goods, only_to_buy)

      event_wait while event_begin_in_shop?
      data.clear if data

      branch(current_command.indent, shop_unit.traded_anything?)
    end
  end

  # 中断から再開した際にのみ呼ばれる
  def command_605(indent, params)
    begin
      back_to_previous_command
    end while current_command.code == EventCode::SHOP_SEQUEL
    # ショップまで戻って再実行する
    execute_command(current_command)
  end

  def event_begin_in_shop?
    map_manager.ui_unit.shop_unit.open?
  end

  # 名前入力欄を開く  
  # @param [Fixnum] actor_id アクターの識別子
  # @oaram [Fixnum] limit 制限文字数
  def event_show_name_input(actor_id, limit)
    raise Itefu::Exception::NotSupported
  end

  # @return [Boolean] 名前入力欄を開いているか
  def event_showing_name_input?; false; end

  def event_change_actor_graphic(actor, chara_name, chara_index, face_name, face_index)
    super
    if party_member?(actor.actor_id)
      player_object.change_companion_graphic(actor.actor_id, chara_name, chara_index)
    end
  end

  def change_vehicle_graphic(vehicle_type, chara_name, chara_index)
    raise Itefu::Exception::NotSupported
  end

  # メニュー画面を開く
  def event_open_field_menu
    event_wait until event_message_closed?
    map_manager.quit(::Map::ExitCode::OPEN_MENU)
  end

  # @return [Boolean] メニュー画面を開いているか
  # @note メニュー画面をマップと同じシーンで処理する場合にはここで待つようにする
  def event_being_in_field_menu?; false; end

  # セーブ画面を開く
  def event_open_save_menu
    event_wait until event_message_closed?
    map_manager.quit(::Map::ExitCode::OPEN_SAVE)
  end

  # @return [Boolean] セーブ画面を開いているか
  # @note セーブ画面をマップと同じシーンで処理する場合にはここで待つようにする
  def event_being_in_save_menu?; false; end

  def event_game_over(ending_type = nil)
    event_wait until event_message_closed?
    SaveData.reset(ending_type)
    map_manager.quit(::Map::ExitCode::CLOSE)
  end

  def event_go_to_title(ending_type = nil)
    if @event_status.data[:go_to_title]
      @event_status.data[:go_to_title] = false
      event_game_over(ending_type)
    else
      @event_status.data[:go_to_title] = true
      event_wait until event_message_closed?
      SaveData.save_map(map_manager)
      SaveData.save_game
      map_manager.quit(::Map::ExitCode::CLOSE, :quit)
    end
  end

end

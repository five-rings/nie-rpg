=begin
  EventInterpreterのアプリ実装
=end
module Event::Interpreter
  include Itefu::Rgss3::EventInterpreter
  def manager; raise Itefu::Exception::NotImplemented; end 
  def database; raise Itefu::Exception::NotImplemented; end 
  def sound; raise Itefu::Exception::NotImplemented; end 
  BRANCH_TEMP = -1
  def map?; false; end
  def battle?; false; end


  # --------------------------------------------------
  # 共通の独自実装

  # @return [Boolean] CommonEventか
  def common_event?
    @parent || event_status.event_id.nil?
  end

  # メッセージの識別子
=begin
  def message_key(index = nil)
    if common_event?
      # CommonEvent
      mid = nil
      eid = nil
      pid = event_status.page_index # id of CommonEvent
    else
      mid = event_status.map_id
      eid = event_status.event_id
      pid = event_status.page_index + 1
    end
    if index
      :"rp#{mid}_#{eid}_#{pid}_#{event_status.program_counter}-sel#{index}"
    else
      :"rp#{mid}_#{eid}_#{pid}_#{event_status.program_counter}"
    end
  end
=end

  # CommonEvents用のlanguageインスタンスを取得する
  def common_message
    raise Itefu::Exception::NotImplemented
  end

  # CommonEvents用のメッセージがあればそれを取得する
  # @note 存在しない場合は空文字を返す
  def common_text(label, *indices)
    text_from_message_with_id(common_message, label, indices) || ""
  end

  # @return [String] 多言語対応テキストがあればそれを返す
  # @param [Language] msg 多言語対応データセット
  # @param [String] text 元文字
  def message_text(msg, text)
    if /^\:([\w-]+)(?:\:([\d,]+))?:([\s\S]+)/ === text
      # ID指定でのメッセージ書き換え
      indices = $2 && $2.split(",").map {|idx| idx && Integer(idx) }
      text_from_message_with_id(msg, $1.intern, indices) || $3
    end
  end

  def text_from_message_with_id(msg, key, indices = nil)
    case m = msg && msg.text(key)
    when Array
      i = 0
      indices ||= []
      begin
        case m = m[indices[i] || 0]
        when Symbol
          m = msg.text(m)
        end
        i += 1
      end while Array === m
      m
    when Symbol
      msg.text(m)
    when String
      m
    else
      ITEFU_DEBUG_OUTPUT_WARNING "unknown message #{key} #{m.inspect}"
      ITEFU_DEBUG_DUMP_EVENT_INFO
    end
  end


  # 変数の操作でbit演算を簡単にするためのヘルパ
  class BitOperation
    attr_reader :value
    alias :to_i :value

    def initialize(value)
      @value = value
    end

    # ビットを立てる
    def +(lhs); lhs | @value; end

    # ビットを降ろす
    def -(lhs); lhs & ~@value; end

    # AND
    def *(lhs); lhs & @value; end

    # XOR
    def /(lhs); lhs ^ @value; end

    # NAND
    def %(lhs); ~lhs | ~@value; end

    # ビットが立っているか
    def ===(rhs); (@value & rhs) == @value; end

    # ビットが立っているか
    def ==(rhs); (@value & rhs) == @value; end

    # ビットが立っていないか
    def !=(rhs); (@value & rhs) != @value; end
  end

  def bit(value)
    BitOperation.new(value)
  end

  # フェード速度の変更（フェード実行でリセット）
  def command_fade_speed(speed_out, speed_in = nil, *args)
    @fade_out = Integer(speed_out)
    if speed_in
      @fade_in = Integer(speed_in)
    else
      @fade_in = @fade_out
    end
  end

  # フェード色を変更（フェード実行でリセット）
  def command_fade_color(r, g, b, *args)
    @fade_color = Itefu::Color.create(
      Integer(r),
      Integer(g),
      Integer(b)
    )
  end


  # --------------------------------------------------
  # 拡張実装

  # ラベルジャンプ時にreturnできるするようにする
  def command_119(indent, params)
    rps = @event_status.data[:return] ||= []
    if params[0].start_with?('*')
      label_name = params[0].clone
      params[0].slice!(0)
      # store returning point
      rps.push @event_status.program_counter
    else
      # 通常のジャンプ時はgoto扱いとしスタックをクリアする
      rps.clear if rps
    end
    super
    params[0] = label_name if label_name
  end

  # ラベルジャンプした場所にreturnする
  def command_115(indent, params)
    rps = @event_status.data[:return]
    rp = rps && rps.pop
    if rp
      # return
      @event_status.program_counter = rp
    else
      super
    end
  end
  def event_wait_115
    # return するときは待たないようにする
    rps = @event_status.data[:return]
    if rps.nil? || rps.empty?
      event_wait_for_message_closing
    end
  end

  # アイテム・武器・防具・お金を取得した際に情報を変数に格納する
  # @param [Fixnum] variable_id 変数のID
  # @note 取得するごとにvariable_idはインクリメントされる
  def picking_info(variable_id)
    @picking_info = @picking_info_start = variable_id
    @picking_info_indent = current_command.indent
    true
  end

  # picking_infoで取得したアイテム情報をidからアイテムのインスタンスに変換する
  def decode_picking_info(variable_id)
    data = variable(variable_id)
    db = case data[0]
      when RPG::Item.kind
        database.items
      when RPG::Weapon.kind
        database.weapons
      when RPG::Armor.kind
        database.armors
      end
    item = db[data[1]]
    [item, data[2]]
  end

  # アイテム・武器・防具追加を抽選の候補として扱う
  def treasure_list(variable_id)
    @treasure_list = []
    @treasure_picking_id = variable_id
    @treasure_list_indent = current_command.indent
  end

  # treasure_listからpicking_info同等のデータを作成する
  def command_pick_from_treasure_list(*args)
    info = change_variable(@treasure_picking_id, @treasure_list.sample || 0)
    # 取得処理が通常扱いになるように
    @treasure_list = nil
    # 各種取得処理
    case info
    when Fixnum
      event_add_money(info)
    when Array
      case info[0]
      when :item
        event_add_item(info[1], info[2])
      when :weapon
        event_add_weapon(info[1], info[2], false)
      when :armor
        event_add_armor(info[1], info[2], false)
      end
    end
    # リセット
    @treasure_list = []
    @treasure_picking_id += 1
  end
  def event_wait_pick_from_treasure_list; end

  def event_wait_125; event_wait_treasure_list; end
  def event_wait_126; event_wait_treasure_list; end
  def event_wait_127; event_wait_treasure_list; end
  def event_wait_128; event_wait_treasure_list; end
  def event_wait_treasure_list
    if @treasure_list
      # nowait
    else
      event_wait_for_message_closing
    end
  end

  # 条件分岐の末尾で自動解除する
  def command_412(indent, *args)
    if @picking_info_indent == indent
      @picking_info_indent = @picking_info = @picking_info_start = nil
    end
    if @treasure_list_indent == indent
      @treasure_list_indent = @treasure_list = @treasure_picking_id = nil
    end
    super
  end

  # アイテムを消費する
  def consume_item_by_id(item_id, count = 1)
    item = SaveData.inventory.find_item_by_id(item_id)
    # 消費
    ret = SaveData.inventory.remove_item_by_id(item_id, count)
    # 減らせ多分だけ大事なものを骨董商へ
    if Game::Agency.important_item?(item)
      SaveData.important.add_item(item, count+ret)
    end
  end

  # ビット演算する場合の対応
  def operated_variable_value(operator, lhs, rhs)
    case rhs
    when BitOperation
      case operator
      when 0  # 代入
        rhs
      else
        super(operator, rhs, lhs)
      end
    else
      super
    end
  end

  def event_fade_out
    manager.fade.fade_color(@fade_color || Itefu::Color.Black, @fade_out || 30, @fade_in || 30)
    @fade_in = @fade_out = nil
    @fade_color = nil
  end

  def event_fade_in
    manager.fade.resolve
  rescue Itefu::Fade::Manager::NotFadedException
    # @todo 再開する際に暗転状態を保存しなくてよいか
    ITEFU_DEBUG_OUTPUT_CAUTION "not faded"
    ITEFU_DEBUG_DUMP_EVENT_INFO
  end

  def event_fading_out?
    manager.fade.faded_out? &&
    manager.fade.fading?
  end

  def event_fading_in?
    manager.fade.faded_out?.! &&
    manager.fade.fading?
  end


  # --------------------------------------------------
  # アプリケーションで実装する必要のある補助機能
  
  def common_event(id)
    database.common_events[id]
  end
  
  include Application::Accessor::Flags
  module SaveData
    extend Application::Accessor::GameData
  end
  module SystemData
    extend Application::Accessor::SystemData
  end
  module Input
    extend Application::Accessor::Input
  end

  def party_members
    SaveData.party.members.map {|id|
      actor_instance(id)
    }
  end
  
  def party_member_id(index)
    SaveData.party.members[index]
  end
  
  def party_member?(id)
    SaveData.party.members.include?(id)
  end

  def actor_instance(id)
    SaveData.actor(id)
  end

  def actor_level(actor)
    actor.level
  end

  def actor_total_exp(actor)
    actor.total_exp
  end

  def actor_hp(actor)
    actor.hp
  end

  def actor_mp(actor)
    actor.mp
  end

  def actor_param(actor, param_id)
    actor.param(param_id)
  end
 
  def actor_name(actor)
    actor.name
  end

  def actor_job_id(actor)
    actor.class_id
  end

  def actor_skill?(actor, skill_id)
    actor.skills.include?(skill_id)
  end

  def actor_weapon?(actor, weapon_id)
    actor.equipments.each_value.find {|item|
      RPG::Weapon === item && item.id == weapon_id
    }.nil?.!
  end
  
  def actor_armor?(actor, armor_id)
    actor.equipments.each_value.find {|item|
      RPG::Armor === item && item.id == armor_id
    }.nil?.!
  end
  
  def actor_state?(actor, state_id)
    actor.in_state_of?(state_id)
  end

  def inventory_item?(item_id)
    SaveData.inventory.has_item?(database.items[item_id])
  end
  
  def inventory_weapon?(weapon_id)
    SaveData.inventory.has_item?(database.weapons[weapon_id])
  end
  
  def inventory_armor?(armor_id)
    SaveData.inventory.has_item?(database.armors[armor_id])
  end
  
  def button_on_pressing?(d)
    Input.pressing?(d)
  end

  def vehicle_on_rode?(vehicle_type)
    raise Itefu::Exception::NotSupported
  end
  
  def number_of_items(item_id)
    SaveData.inventory.number_of_item(database.items[item_id])
  end
  
  def number_of_weapons(weapon_id)
    SaveData.inventory.number_of_item(database.weapons[weapon_id])
  end
  
  def number_of_armors(armor_id)
    SaveData.inventory.number_of_item(database.armors[armor_id])
  end

  def number_of_party_members
    SaveData.party.members.size
  end
  
  def amount_of_money
    SaveData.party.money
  end
  
  def number_of_steps
    SaveData.system.count_of_steps
  end
  
  def amount_of_playing_time
    SaveData.playing_time
  end
  
  # タイマー計測値ではなくフレームタイマーの値を取得する
  def count_of_timer
    Application.timer.frame_time
  end
  
  def count_of_saving
    SaveData.system.count_of_saving
  end
  
  def count_of_battle
    SaveData.system.count_of_battle
  end

  def this_switch(key)
    self_switch(event_status.map_id, event_status.event_id, key) == true
  end
  

  # --------------------------------------------------
  # アプリケーションで実装する必要のあるイベントの処理

  # タイマーのカウントダウンを開始する
  # @param [Fixnum] frame_to_count_down タイマーの初期値
  # @note frame_to_count_down は時間で入力した値が60fpsでのフレーム数に換算されて与えられる
  def event_start_timer(frame_to_count_down)
    raise Itefu::Exception::NotImplemented
  end

  # タイマーを停止する
  def event_stop_timer
    raise Itefu::Exception::NotImplemented
  end
  
  def event_timer_working?
    false
  end
  
  def event_add_money(diff)
    if @treasure_list
      @treasure_list << diff
      return
    end

    SaveData.party.add_money(diff)
    if @picking_info && diff > 0
      id_to_sum = (@picking_info_start...@picking_info).find {|id|
        Fixnum === variable(id)
      }
      if id_to_sum
        change_variable(id_to_sum, variable(id_to_sum) + diff)
      else
        change_variable(@picking_info, diff)
        @picking_info += 1
      end
    end
  end

  # 持ち物にオブジェクト(idではなく)を指定して追加／削除を行う
  def event_add_item_to_inventory(item, diff, strip = false)
    if @treasure_list
      limit = item.special_flag(:amount)
      @treasure_list << [item.kind, item.id, diff] if limit.nil? || SaveData.number_of_item(item) < limit
      return
    end

    if @picking_info && diff > 0
      change_variable(@picking_info, [item.kind, item.id, diff])
      @picking_info += 1
    end
    diff = SaveData.inventory.add_item(item, diff)
    if strip && diff < 0
      event_remove_item_from_equipment(item, -diff)
    end
  end
  
  def event_add_item(item_id, diff)
    item = database.items[item_id]

    if @treasure_list
      limit = item.special_flag(:amount)
      @treasure_list << [item.kind, item.id, diff] if limit.nil? || SaveData.number_of_item(item) < limit
      return
    end

    SaveData.inventory.add_item(item, diff)
    if @picking_info && diff > 0
      id_to_sum = (@picking_info_start...@picking_info).find {|id|
        d = variable(id)
        Array === d && d[0] == item.kind && d[1] == item.id
      }
      if id_to_sum
        data = variable(id_to_sum)
        data[2] += diff
      else
        change_variable(@picking_info, [item.kind, item.id, diff])
        @picking_info += 1
      end
    end
  end
  
  # パーティメンバーの装備品から指定したアイテムを指定個数減らす
  # @note diffは減らしたい個数を正の数で指定する
  # @return [Fixnum] 減らし切れなかった個数を返す
  def event_remove_item_from_equipment(item, diff)
    return 0 unless diff > 0
    SaveData.party.members.each do |actor_id|
      actor = actor_instance(actor_id)
      actor.equipments.each do |pos, equip|
        next unless equip &&
                    equip.kind == item.kind &&
                    equip.id == item.id
        # 減らしたいアイテムを装備していた
        actor.unquip(pos)
        diff -= 1
        return 0 if diff <= 0
      end
    end
    diff
  end
  
  def event_add_weapon(weapon_id, diff, strip)
    item = database.weapons[weapon_id]
    event_add_item_to_inventory(item, diff, strip)
  end

  def event_add_armor(armor_id, diff, strip)
    item = database.armors[armor_id]
    event_add_item_to_inventory(item, diff, strip)
  end

  def event_join_party(actor_id, init)
    SaveData.party.add_member(actor_id)
    SaveData.reset_actor(actor_id) if init
  end

  def event_leave_party(actor_id)
    SaveData.party.remove_member(actor_id)
  end
  
  def event_change_battle_bgm(bgm)
    if bgm.nil? || bgm.name.empty?
      SaveData.system.battle_bgm = nil
    else
      SaveData.system.battle_bgm = bgm
    end
  end
  
  def event_change_battle_me(me)
    if me.nil? || me.name.empty?
      SaveData.system.battle_me = nil
    else
      SaveData.system.battle_me = me
    end
  end

  def event_change_save_prohibition(prohibited)
    SaveData.system.to_save = prohibited.!
  end

  def event_change_menu_prohibition(prohibited)
    SaveData.system.to_open_menu = prohibited.!
  end

  def event_change_encounter_prohibition(prohibited)
    SaveData.system.to_encounter = prohibited.!
  end

  def event_change_formation_prohibition(prohibited)
    # 並び替え禁止をアイテムの捨てるのを禁止に流用する
    SaveData.system.not_to_discard = prohibited
  end

  def event_play_bgm(bgm)
    sound.play(bgm)
  end

  def event_stop_bgm(rt)
    sound.stop_bgm(rt)
  end

  def event_cache_bgm
    SaveData.system.cached_bgm = sound.actual_bgm
  end

  def event_restore_bgm
    bgm = SaveData.system.cached_bgm
    sound.play(bgm) if bgm
  end

  def event_play_bgs(bgs)
    sound.play(bgs)
  end

  def event_stop_bgs(rt)
    sound.stop_bgs(rt)
  end

  def event_play_me(me)
    sound.stop_me
    sound.play(me)
  end
  
  def event_play_se(se)
    sound.play(se)
  end
  
  def event_stop_se
    sound.stop_se
  end

  def event_change_if_show_map_name(to_show)
    SaveData.change_if_show_map_name(to_show)
  end

  def event_change_battle_background(back1, back2)
    SaveData.system.battle_floor = back1
    SaveData.system.battle_wall  = back2
  end

  def event_add_actor_hp(actor, diff, to_die)
    actor.add_hp(diff, to_die)
  end

  def event_add_actor_mp(actor, value)
    actor.add_mp(value)
  end

  def event_append_actor_state(actor, state_id)
    actor.add_state(state_id, true)
  end

  def event_remove_actor_state(actor, state_id)
    actor.remove_state(state_id)
  end
  
  def event_recover_actor(actor)
    actor.recover_all
  end
  
  def event_add_actor_exp(actor, diff, to_notify)
    skills = actor.skills_raw.clone if to_notify
    old_level = actor.level
    old_job_name = actor.job_name
    actor.add_exp(diff)
    if actor.level > old_level
      actor.recover_by_leveling_up(old_level)
      if to_notify
        skills = actor.skill_diffs(skills)
        show_level_up_message(actor, actor.level, old_level, skills, old_job_name)
      end
    end
  end

  def event_add_actor_level(actor, diff, to_notify)
    skills = actor.skills_raw.clone if to_notify
    old_level = actor.level
    old_job_name = actor.job_name
    actor.add_level(diff)
    if actor.level > old_level
      actor.recover_by_leveling_up(old_level)
      if to_notify
        skills = actor.skill_diffs(skills)
        show_level_up_message(actor, actor.level, old_level, skills, old_job_name)
      end
    end
  end

  def show_level_up_message(actor, new_level, old_level, learnt_skills, old_job_name)
    diff_level = new_level - old_level
    return unless fmt_levelup = Application.language.message(:game, :level_up)
    return unless fmt_levelup_newjob = Application.language.message(:game, :level_up_newjob)
    return unless fmt_skill = Application.language.message(:game, :learnt_skill_indent)
    event_wait until event_message_closed?

    if newjobname = actor.job.highjob_name(new_level, old_level)
      message = sprintf(fmt_levelup_newjob, old_job_name, newjobname, old_level, new_level)
      vacant = 1 # @magic 1 = 4 lines in the window - 3 lines of fmt_levelup_newjob
    else
      message = sprintf(fmt_levelup, actor.job_name, old_level, new_level)
      vacant = 2 # @magic 2 = 4 lines in the window - 2 lines of fmt_levelup
    end

    vacant.times {
      if sid = learnt_skills.shift
        message << Itefu::Rgss3::Definition::MessageFormat::NEW_LINE
        message << sprintf(fmt_skill, sid)
      end
    }

    sound.stop_me
    sound.play_me("Victory1", 90, 95)

    until message.empty?
      event_show_message(message, actor.face_name, actor.face_index, 0, 2)
      event_wait while event_message_showing?

      message.clear
      # @magic ウィンドウに4行表示できる
      4.times {
        if sid = learnt_skills.shift
          message << sprintf(fmt_skill, sid)
          message << Itefu::Rgss3::Definition::MessageFormat::NEW_LINE
        end
      }
    end
    event_wait until event_message_closed?
  end

  def event_add_actor_param(actor, param_id, diff)
    actor.add_param(param_id, diff)
  end

  def event_learn_actor_skill(actor, skill_id)
    actor.learn_skill(skill_id)
  end

  def event_forget_actor_skill(actor, skill_id)
    actor.forget_skill(skill_id)
  end

  def event_change_actor_equipment(actor, slot_id, equip_id)
    return unless pos = Definition::Game::Equipment.convert_from_rgss3(slot_id)
    if equip_id != 0
      item =  case slot_id
              when Itefu::Rgss3::Definition::Equipment::Slot::WEAPON
                database.weapons[equip_id]
              else
                database.armors[equip_id]
              end
      if item.special_flag(:material)
        # 素材アイテムを装備しようとしたときは今の装備品を強化する
        if base_item = actor.equipment(pos)
          base_item.assign_extra_item(item)
          actor.clamp_hp_mp
        else
#ifdef :ITEFU_DEVELOP
          ITEFU_DEBUG_OUTPUT_WARNING "Intended to set a material #{item.name} but Actor #{actor.name} has no equip in slot #{pos}"
          ITEFU_DEBUG_DUMP_EVENT_INFO
#endif
        end
      else
        # 装備を切り替える
        if old = actor.equipment(pos)
          # 装備を持ち物に戻す
          SaveData.inventory.add_item(old)
        end
        actor.equip(pos, item)
      end
    else
      # 装備を外す
      if old = actor.equipment(pos)
        # 装備を持ち物に戻す
        SaveData.inventory.add_item(old)
      end
      actor.unequip(pos)
    end
  end

  def event_change_actor_name(actor, name)
    actor.name = name
  end

  def event_change_actor_graphic(actor, chara_name, chara_index, face_name, face_index)
    actor.chara_name  = chara_name
    actor.chara_index = chara_index
    actor.face_name   = face_name
    actor.face_index  = face_index
  end

  def event_change_actor_job(actor, job_id)
    actor.change_class(job_id)
  end

  def event_change_actor_nickname(actor, nickname)
    actor.nickname = nickname
  end

end

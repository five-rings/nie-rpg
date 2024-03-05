=begin
  FormatStringのタイトル側実装
=end
module Layout::Control::FormatString

  SPECIAL_ICONS = {
    "$" => 262,   # 通貨
    "#" => 361,   # スキルトークン
  }

  # @return [String] アクターの名前を返す
  def actor_name(actor_id)
    if actor_id
      actor = Application.savedata_game.actors[actor_id]
      actor && actor.name
    end
  end

  # @return [String] パーティメンバーの名前を返す
  def member_name(member_index); raise Itefu::Exception::NotImplemented; end

  # @return [String] 変数の内容を返す
  def variable(index)
    Application.savedata_game.flags.variables[index]
  end

  # @return [String] 通貨の単位を返す
  def currency_unit; Application.database.system.rawdata.currency_unit; end

  # 
  # 独自のコマンドの書き換え

  COMMAND_PREFIX = Itefu::Rgss3::Definition::MessageFormat::COMMAND_PREFIX
  Command = Itefu::Rgss3::Definition::MessageFormat::Command
  CommandPattern = Itefu::Rgss3::Definition::MessageFormat::CommandPattern

  def replace_text(text)
    text = super
    return text if text.empty?

    items = Application.database.items
    text.gsub!(CommandPattern::ITEM_NAME) {
      items[Integer($1)].name rescue nil
    }

    weapons = Application.database.weapons
    text.gsub!(CommandPattern::WEAPON_NAME) {
      weapons[Integer($1)].name rescue nil
    }

    armors = Application.database.armors
    text.gsub!(CommandPattern::ARMOR_NAME) {
      armors[Integer($1)].name rescue nil
    }

    enemies = Application.database.enemies
    text.gsub!(CommandPattern::ENEMY_NAME) {
      enemies[Integer($1)].name rescue nil
    }

    skills = Application.database.skills
    text.gsub!(CommandPattern::SKILL_NAME) {
      skills[Integer($1)].name rescue nil
    }

    text.gsub!(CommandPattern::ITEM_COUNT) {
      Application.savedata_game.inventory.number_of_item_by_id(Integer($1)) rescue nil
    }

    text.gsub!(CommandPattern::MP_COST) {
      if skill = skills[Integer($1)]
        if skill.use_all_mp?
          "∞" # @todo 
        else
          skill.mp_cost
        end
      end
    }

    text.gsub!(CommandPattern::SKILL_DESCRIPTION) {
      if skill = skills[Integer($1)]
        skill.description.gsub( Itefu::Rgss3::Definition::MessageFormat::CRLF, Itefu::Rgss3::Definition::MessageFormat::NEW_LINE)
      end
    }

    text.gsub!(CommandPattern::MONEY) {
      "\\{[2]\\I[$]\\}[2]#{Itefu::Utility::String.number_with_comma($1)}\\}[16] \\{[16]#{currency_unit}"
    }

    text.gsub!(CommandPattern::NUMERAL) {
      begin
        Itefu::Utility::String.number_with_comma(Integer($1))
      rescue
        $1
      end
    }

    text.gsub!(CommandPattern::SPECIAL_ICON) {
      "#{COMMAND_PREFIX}#{Command::SPECIAL_ICON}[#{SPECIAL_ICONS[$1] || 0}]"
    }

    text
  end
end

class Layout::Control::TextArea < Itefu::Layout::Control::TextArea
  include Layout::Control::FormatString
end

class Layout::Control::Text < Itefu::Layout::Control::Text
  include Layout::Control::FormatString
end

module Itefu::Rgss3::Definition::MessageFormat
  module Command
    ITEM_NAME    = 'i'
    WEAPON_NAME  = 'w'
    ARMOR_NAME   = 'a'
    ENEMY_NAME   = 'e'
    SKILL_NAME   = 's'
    ITEM_COUNT    = 'ni'
    MP_COST      = 'm'
    SKILL_DESCRIPTION = 'ds'
    SPECIAL_ICON = 'I'
    MONEY = 'g'
    NUMERAL = 'num'
  end

  module CommandPattern
    ARMOR_NAME = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::ARMOR_NAME}\[(\d+)\]/o
    WEAPON_NAME = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::WEAPON_NAME}\[(\d+)\]/o
    ITEM_NAME = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::ITEM_NAME}\[(\d+)\]/o
    ENEMY_NAME = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::ENEMY_NAME}\[(\d+)\]/o
    SKILL_NAME = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::SKILL_NAME}\[(\d+)\]/o
    ITEM_COUNT = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::ITEM_COUNT}\[(\d+)\]/o
    MP_COST = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::MP_COST}\[(\d+)\]/o
    SKILL_DESCRIPTION = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::SKILL_DESCRIPTION}\[(\d+)\]/o
    SPECIAL_ICON = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::SPECIAL_ICON}\[([^\[\]])\]/o
    MONEY = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::MONEY}\[(\d+)\]/o
    NUMERAL = /#{Regexp.escape(COMMAND_PREFIX)}#{Command::NUMERAL}\[(\d+)\]/o
  end
end


=begin
=end
module Database::Table

  module ReplaceText
    def replace_text; end
  end

  module Language
    def message_id; :database; end

    # DBで定義されたテキストを言語ファイルの定義で置き換える
    # @return [Boolean] 指定した置き換え対象のテキストが存在したか
    def replace_db_text(label, method, target = @rawdata)
      replaced = false
      message = Application.language.load_message(message_id)
      target.each.with_index do |entry, id|
        if text = message.text((label + id.to_s).intern)
          entry.send(method, text)
          replaced = true
        end
      end
      Application.language.release_message(:database)
      replaced
    end
  end

end

class Itefu::Database::Table::Base
  include Database::Table::ReplaceText
end


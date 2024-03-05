=begin
=end
class Language
  include Itefu::Language::Loader

  def message_klass; Language::Message; end

  def load_message(id, locale = nil)
    super(id, Filename::Language::PATH, "#{id}.dat", locale)
  end
  
  def reload_messages(locale = nil)
    super(Filename::Language::PATH, locale)
  end

  module Locale
    module Target
      include Itefu::Language::Locale
    end
    include Target
    DEFAULT = EN_US   # システムの言語が翻訳非対応の場合に選ばれる

    # 文字幅が全角を基準とするか
    def self.full?(locale = nil)
      @fulls && @fulls[locale || Itefu::Language::locale] == true
    end

    # 言語ごとに指定されたフォントがあればそれを使う
    def self.default_font(locale = nil)
      @default_fonts && @default_fonts[locale || Itefu::Language::locale]
    end

    # 文字幅を半角基準とするか
    def self.half?; full?.!; end

    # 使用可能な言語
    def self.availables; @availables; end

    # 使用可能な言語か
    def self.available?(locale); @labels.has_key?(locale); end

    # 言語の表記
    def self.label(locale); @labels[locale]; end

    # 言語の表記一覧
    def self.labels; @labels; end

    # 別の言語に切り替え可能か
    def self.switchable?; availables && availables.size >= 2; end

    # 使用可能な言語をリストアップする
    def self.check_languages_available
      language = Language.new
      msg = language.load_message(:lang_info)

      # パック済みデータから確認
      @labels = {}
      @availables = []
      @fulls = {}
      @default_fonts = {}

      Target.constants.each do |key|
        locale = Language::Locale::Target.const_get(key)
        language.reload_messages(locale)
        if (label = msg.text(:lang_info)) && label.empty?.!
          @availables << locale
          @labels[locale] = label
          @fulls[locale] = true if msg.text(:full_width)
          @default_fonts[locale] = msg.text(:font)
        end
      end

      # 追加フォルダを確認
      additionals = []

      Dir.foreach(Filename::Language::PATH) do |entry|
        next if entry.start_with?(".")
        next unless File.directory?("./#{Filename::Language::PATH}/#{entry}")
        additionals << entry.intern
      end if File.directory?(Filename::Language::PATH)

      additionals.each do |locale|
        language.reload_messages(locale)
        if (label = msg.text(:lang_info)) && label.empty?.!
          unless @labels.has_key?(locale)
            @availables << locale # 非既存のもののみ追加
          end
          @labels[locale] = label # 表記は上書きできるようにする
          @fulls[locale] = true if msg.text(:full_width)
          @default_fonts[locale] = msg.text(:font)
        end
      end

      language.release_all_messages
    end

    # 次の使用可能な言語を探す
    def self.rotate(diff, locale = Itefu::Language.locale)
      check_languages_available unless @availables
      index = @availables.find_index {|l|
        l == locale
      }
      return DEFAULT unless index

      index = Itefu::Utility::Math.loop_size(@availables.size, index + diff)
      @availables[index] || DEFAULT
    end

    # 文字列からロケールの定数を返す
    def self.getLocaleFromString(str)
      locale = str.downcase.gsub("-","_").intern
      @availables.find {|l|
        l == locale
      }
    end

  end
end

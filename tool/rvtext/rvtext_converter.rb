=begin
  rvlangcの変換処理
=end

require 'fileutils'

module Rvtext
module Converter
  OUTPUT_EXT = 'dat'
  class InvalidIdError < StandardError; end
  SEPARATORS = File.open("separator.txt", "r:utf-8") {|f| f.read.gsub(/[\r\n]/, "") }

  # 指定されたフォルダにあるファイルのうち除外リストにあるもの以外の全てを変換する
  # @param [String] input_path 対象のファイルが置かれたフォルダ
  # @param [String] output_path 変換したファイルを作成するフォルダ
  # @param [Array<String>] excludes 無視リスト
  def self.convert_all(input_path, output_path, excludes)
    # ディレクトリ一覧からファイルリストを作成する
    filelist = Dir.chdir(input_path) {
      Dir.glob("**/*").select {|filename|
        next false unless File.file?(filename)
        next false if excludes.any? {|pattern| filename.match(Regexp.compile(pattern)) }
        true
      }
    }
    convert_files(input_path, output_path, filelist)
  end

  # ファイルリストにあるファイルを全て変換する
  # @param [String] input_path 対象のファイルが置かれたフォルダ
  # @param [String] output_path 変換したファイルを作成するフォルダ
  # @param [Array<String>] files 変換する対象のファイル
  def self.convert_files(input_path, output_path, files)
    # リストにあるファイルそれぞれを変換する
    files.each do |file|
      convert("#{input_path}/#{file}", output_path, file)
    end
  end

  # 指定されたファイルを変換する
  # @param [String] 変換するファイル
  # @param [String] output_path 変換したファイルを作成するフォルダ
  # @param [String] output_name 変換したファイルのファイル名(output_pathからの相対パス)
  def self.convert(input, output_path, output_name)
    @context = Context.new(output_name)

    File.open(input, "r") {|f|
      f.each_line do |line|
        parse_line(line.strip)
      end
    }

    @context.finish
    store(output_path + "/" + output_name, @context.data)
  end

  # 変換されたデータを保存する
  def self.save_stored_data
    @data.each do |filename, data|
      save(filename, data)
    end
    @data.clear
  end

private
  # 変換したデータをためておく
  def self.store(output, data)
    name = "#{File.dirname(output)}.#{OUTPUT_EXT}"
    @data ||= {}
    h = @data[name] ||= {}
    data.each do |key, value|
      if h.has_key?(key)
        $stderr.puts "label:#{key} is duplicated in #{File.basename(name)}"
      else
        h[key] = value
      end
    end
  end

  # ファイルに保存する
  def self.save(output, data)
    dirname = File.dirname(output)
    FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
    File.open(output, "wb") {|f|
      Marshal.dump(data, f)
    }
  end

  class Context
    attr_reader :file
    attr_reader :data

    def initialize(file)
      @file = file
      @current_label = nil
      @texts = []
      @current_messages = []
      @data = {}
    end

    def finish
      make_message
      change_label(nil)
    end

    def change_label(label)
      dump_to_data(@current_label)
      @current_label = label
    end

    def make_message
      message = @texts.join("\n")
      message.rstrip!
      unless message.empty?
        @current_messages << message
      end
      @texts.clear
    end

    def push_text(text)
      @texts << text
    end

    def jump(label)
      @current_messages << label
    end

    def choice(label, text)
      if label.start_with?('-')
        label = :"#{@current_label}#{label}"
      else
        label = label.intern
      end
      if data.has_key?(label)
        $stderr.puts "label:#{label} is duplicated in #{@file}"
      end
      @data[label] = text
    end

    def dump_to_data(label)
      return if @current_messages.empty?
      if data.has_key?(label)
        $stderr.puts "label:#{label} is duplicated in #{@file}"
      end
      @data[label] = Array.new(@current_messages)
      @current_messages.clear
    end
  end

  # テキストファイルを解析する
  def self.parse_line(text)
    case text
    when /^#/
      # コメント行
      return
    when /^:([A-Za-z][A-Za-z0-9_-]*)/
      # ラベルの指定
      @context.make_message
      @context.change_label($1.intern)
    when /^jump\s*:([A-Za-z][A-Za-z0-9_-]*)/
      # ラベルの参照
      @context.make_message
      @context.jump($1.intern)
    when /^\*\s*([A-Za-z-][A-Za-z0-9_-]*)\s+(.*)/
      @context.make_message
      @context.choice($1, $2)
    else
      # テキストメッセージ
      parse_text(text)
    end
  end

  # テキストメッセージを解析する
  def self.parse_text(text)
    if /^([#{SEPARATORS}])\s*(.*)/o === text
      # テキスト区切り
      @context.make_message
#      @context.push_text($1+$2)
    else
      # 追加の文章
      @context.push_text(text)
    end
  end

end
end


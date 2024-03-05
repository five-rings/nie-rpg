=begin
  rvlangcの変換処理
=end

require 'roo'

module Rvlangc
module Converter
  OUTPUT_EXT = 'dat'
  class InvalidIdError < StandardError; end

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
      dirname = File.dirname(file)
      basename = File.basename(file, ".*")
      convert("#{input_path}/#{file}", output_path, "#{dirname}/#{basename}.#{OUTPUT_EXT}")
    end
  end

  # 指定されたファイルを変換する
  # @param [String] 変換するファイル
  # @param [String] output_path 変換したファイルを作成するフォルダ
  # @param [String] output_name 変換したファイルのファイル名(output_pathからの相対パス)
  def self.convert(input, output_path, output_name)
    messages = { nil => {} }
    roo = Roo::Spreadsheet.open(input)

    roo.sheets.each do |sheet|
      roo.default_sheet = sheet
     
      # データ定義をしている行列を探す
      row_def_field = roo.first_row
      col_id_field = 1.upto(roo.last_column).find {|col_index|
        roo.cell(row_def_field, col_index).nil?.!
      }
      
      col_default_field = col_id_field + 1
      col_lang_field_start = col_default_field + 1

      # 設定されている言語用にバッファを作成
      col_lang_field_start.upto(roo.last_column).each do |col_index|
        lang = roo.cell(row_def_field, col_index)
        messages[lang] ||= {} if lang
      end

      # テキストデータを言語ごとに取り出していく
      (row_def_field + 1).upto(roo.last_row).each do |row_index|
        begin
          id = roo.cell(row_index, col_id_field).intern
        rescue
          raise InvalidIdError, "Invalid id.`#{id}' specified at (#{row_index}, #{col_id_field})"
        end

        raise InvalidIdError, "Id.`#{id}' is duplicated at (#{row_index}, #{col_id_field})" if messages[nil].has_key?(id)
        
        # デフォルト
        data = roo.cell(row_index, col_default_field)
        messages[nil].store id, data if data
        # 各言語
        col_lang_field_start.upto(roo.last_column).each do |col_index|
          lang = roo.cell(row_def_field, col_index)
          next unless lang
          data = roo.cell(row_index, col_index)
          messages[lang].store id, data if data
        end
      end
    end

    messages.each do |lang, message|
      if lang
        output = "#{output_path}/#{lang}/#{output_name}"
      else
        output = "#{output_path}/#{output_name}"
      end
      save(output, message)
    end
  end

private
  def self.save(output, data)
    dirname = File.dirname(output)
    FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
    File.open(output, "wb") {|f|
      f.write Marshal.dump(data)
    }
  end

end
end


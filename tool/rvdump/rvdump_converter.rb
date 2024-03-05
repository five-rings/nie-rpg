=begin
  rvdumpの変換処理
=end

require 'fileutils'

module Rvdump 
module Converter
  OUTPUT_EXT = 'dat'

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
  # @param [String] input 変換するファイル
  # @param [String] output_path 変換したファイルを作成するフォルダ
  # @param [String] output_name 変換したファイルのファイル名(output_pathからの相対パス)
  def self.convert(input, output_path, output_name)
    File.open(input, "r") {|f|
      save("#{output_path}/#{output_name}", f.read)
    }
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


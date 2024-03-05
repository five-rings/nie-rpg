#! ruby -Ku
# coding: utf-8

=begin
  テキストファイルを読み込み、ファイルにMarshal.dumpする
=end

Version = '1.0.0'

require_relative './rvdump_converter'
require 'optparse'

module Rvdump
  Options = Struct.new('Options', :input, :output, :exclude, :usepipe)
  class InvalidArgument < ArgumentError; end

  def self.run(argv)
    options = parse_arguments(argv)

    # 除外リストを作成する
    excludes =
      options.exclude &&
      File.open(options.exclude, "r") {|f|
        f.readlines.map(&:chomp)
      } || []

    # 変換を行う
    if File.directory?(options.input)
      if options.usepipe && File.pipe?($stdin)
        # パイプ経由で渡されたファイルリストを対象に変換する
        filelist = $stdin.each_line.map(&:chomp)
        Converter::convert_files(options.input, options.output, filelist)
      else
        # 指定されたフォルダにあるファイルのうち除外リストにあるもの以外を全て変換する
        Converter::convert_all(options.input, options.output, excludes)
      end
    else
      # 指定されたファイルを変換する
      path = File.dirname(options.output)
      name = File.basename(options.output)
      Converter::convert(options.input, path, name)
    end
  end

  # @return [Options]
  def self.parse_arguments(argv)
    options = Options.new
    optparser = OptionParser.new

    def optparser.error(msg = nil)
      warn msg if msg
      warn help()
      raise InvalidArgument, msg
    end

    define_options(optparser, options)
    begin
      optparser.parse(argv)
    rescue OptionParser::ParseError => err
      optparser.error err.message
    end

    validate_options(optparser, options)
    options
  end

  def self.define_options(optparser, options)
    optparser.on("-s", "--source=DIR|FILE", "source directory or file") do|val|
      options.input = val
    end
    
    optparser.on("-o", "--output=DIR|FILE", "destination directory or file") do|val|
      options.output = val
    end
    
    optparser.on("-e", "--excludes=FILE", "exclude list") do|val|
      options.exclude = val
    end

    optparser.on("--usepipe") do
      options.usepipe = true
    end
  end

  def self.validate_options(optparser, options)
    unless options.input && File.exist?(options.input)
      optparser.error %Q(input file or directory "#{options.input}" is not found)
    end

    unless options.output
      optparser.error %Q(output file or directory "#{options.output}" is not specified)
    end
    
    if File.directory?(options.input) && File.directory?(options.output).!
      optparser.error %Q(input is a directory but output is not a directory)
    end
    
    if File.file?(options.input) && (File.exists?(options.output) && File.file?(options.output).!)
      optparser.error %Q(input is a file but output is not a file)
    end

    if options.exclude && File.file?(options.exclude).!
      optparser.error %Q(exclude list "#{options.exclude}" is not a file)
    end
  end
end

begin
  Rvdump.run(ARGV)
rescue Rvdump::InvalidArgument
  # command-line arguments are invalid
  exit 1
end


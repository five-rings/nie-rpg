#! ruby -Ku
# coding: utf-8

=begin
  .graphmlをパースしてItefu::BehaviorTreeの木構造を設定するコードを生成する。
=end

Version = "0.2.7"

require_relative "./btc_converter"
require "optparse"

module Btc
  Options = Struct.new("Options", :input, :output, :exclude, :modes, :usepipe)
  class InvalidArgument < StandardError; end

  # @parma [Array] argv
  def self.run(argv, stdout = $stdout)
    options = parse_arguments(argv)
  
    # [Array<String>]
    excludes =
      options.exclude &&
      open(options.exclude) {|f|
        f.readlines.collect {|line| line.chomp }
      } || []
 
    # convert
    if File.directory?(options.input)
      filelist = []
      if File.pipe?($stdin) && options.usepipe
        $stdin.each_line do |file|
          filelist.push file.chomp
        end
      end
      if filelist.empty?
        Converter::convert_all(options.modes, options.input, options.output, excludes)
      else
        Converter::convert_files(options.modes, options.input, options.output, filelist, excludes)
      end
    else
      Converter::convert(options.modes, options.input, ".", options.output)
    end
  end

  # @return [Options]
  # @parma [Array] argv
  def self.parse_arguments(argv)
    options = Options.new(nil)
    options.modes = []
    optparser = OptionParser.new

    def optparser.error(msg = nil)
      warn msg if msg
      warn help()
      raise InvalidArgument
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
    optparser.on("-s", "--sourte=DIR|FILE", "source directory or file") do|val|
      options.input = val
    end
    
    optparser.on("-o", "--output=DIR|FILE", "destination directory or file") do|val|
      options.output = val
    end
    
    optparser.on("-e", "--excludes=FILE", "exclude list") do|val|
      options.exclude = val
    end

    optparser.on("-b", "--binary", "output as binary file") do
      options.modes.push(:binary)
    end

    optparser.on("--usepipe") do
      options.usepipe = true
    end
  end
  
  def self.validate_options(optparser, options)
    unless options.input && File.exist?(options.input)
      optparser.error %Q(input file or directory "#{options.input}" is not found)
    end

    unless options.output && File.exists?(options.output)
      optparser.error %Q(output file or directory "#{options.output}" is not found)
    end
    
    if File.directory?(options.input) && File.directory?(options.output).!
      optparser.error %Q(input is a directory but output is not directory)
    end
    
    if File.file?(options.input) && File.file?(options.output).!
      optparser.error %Q(input is a file but output is not file)
    end

    if options.exclude && File.file?(options.exclude).!
      optparser.error %Q(exclude list "#{options.exclude}" is not a file)
    end
  end
  
end

begin
 Btc.run(ARGV)
rescue Btc::InvalidArgument
  # The command-line arguments are invalid
  exit 1
end

=begin
  MapInfosを参照して指定したマップ以下のファイルをダンプする
=end
require "optparse"
require_relative "../rv2da/rpg"

#param
# MapInfosの場所
# 出力するファイル
# 指定するマップID
Options = Struct.new("Options", :mapinfos, :output, :ids, )
class InvalidArgument < StandardError; end

def run(argv)
  options = parse_arguments(argv)

   mapinfo = File.open(options.mapinfos, "rb") {|f|
     Marshal.load(f)
   }
   
   removes = [] + options.ids
   processing = true
   while processing
     processing = false
     mapinfo.delete_if do |k,v|
       if removes.include?(v.parent_id)
         removes << k
         processing = true
       end
     end
   end
   
   File.open(options.output, "w") {|f|
     f.puts removes.map {|v| "%03d" % v }
   }
   puts removes.inspect
end

def parse_arguments(argv)
  options = Options.new(nil)
  optparser = OptionParser.new

  def optparser.error(msg = nil)
    warn msg if msg
    warn help()
    raise ::InvalidArgument
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

def define_options(optparser, options)
  optparser.on("-s", "--source=FILE", "path to MapInfos") do|val|
    options.mapinfos = val
  end

  optparser.on("-o", "--output=FILE", "destination file") do|val|
    options.output = val
  end
  
  optparser.on("-i", "--ids=NUMBERS", "id(s) of root map") do|val|
    options.ids = val.split(",").map {|v| Integer(v) }
  end
end
  
def self.validate_options(optparser, options)

  unless options.mapinfos && File.exist?(options.mapinfos)
    optparser.error %Q("#{options.mapinfos}" is not found)
  end

  if options.ids.nil? || options.ids.empty?
    optparser.error %Q(-i is must be specified)
  end
end

begin
  run(ARGV)
rescue InvalidArgument
  exit 1
end

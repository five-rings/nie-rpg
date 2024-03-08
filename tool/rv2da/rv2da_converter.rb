=begin
  convert to json or rvdata2
=end

require "json"
require "find"
require_relative "./rv2da_jsonobject"
require_relative "./rpg"

module Rv2da
  module Converter
    class InvalidFormatedFile < StandardError; end
  
    # @param [String] dirname
    # @param [String] outout
    # @param [Array<String>] excludes
    def convert_all(dirname, output, excludes = [])
      convert_all_files_in_directory(dirname, output, excludes)
    end
    
    # @param [String] dirname
    # @param [String] outout
    # @param [Array<String>] excludes
    def convert_all_files_in_directory(dirname, path_out, excludes = [])
      Find.find(dirname) do|filename|
        begin
          obj = convert(filename, target_extension, excludes)
        rescue InvalidFormatedFile => err
          warn err.message
          obj = nil
        end
        next unless obj

        name = File.basename(filename, ".*")
        save("#{path_out}/#{name}#{extension}", obj)
      end
    end
  
    # @param [String] filename
    # @param [String] target_ext
    # @param [Array<String>] excludes
    def convert(filename, target_ext = "", excludes = [])
      return unless matched = /([^\/]+)#{target_ext}$/.match(filename)
      return if excludes.any? {|pattern| filename.match(Regexp.compile(pattern)) }
      inner_convert(filename, matched[1])
    end
  
    # @param [String] filename
    # @param [Object] obj
    def save(filename, obj); end
    
    # @return [String]
    def extension; end
    
    # @return [String]
    def target_extension; end
    
    # @param [String] filename
    # @param [String] name
    def inner_convert(filename, name); end

  end
end

# rvdata2を分解する
class Rv2da::Converter::Decomposition
  extend Rv2da::Converter 
  class << self
    
    def extension
      ".json"
    end
    
    def target_extension
      ".rvdata2"
    end
    
    def save(filename, obj)
      File.open(filename, "w") {|f| f.write obj }
    end
    
    private
    
    def inner_convert(filename, name)
      JSON.pretty_generate(load_rvdata2(filename))
    end

    # @return [Object]
    # @param [String] filename
    # @raise [InvalidFormatedFile]
    def load_rvdata2(filename)
      begin
        File.open(filename, "rb") {|f|
          Marshal.load(f)
        }.tap {|d|
          case d
          when RPG::System
            d.version_id = 0
            d.edit_map_id = 1
            d.start_map_id = 1
            d.start_x = 0
            d.start_y = 0
            d.test_troop_id = 1
            d.battleback1_name = ""
            d.battleback2_name = ""
            d.battler_name = ""
            d.battler_hue = 0
          when Hash
            d.each_value do |m|
              next unless RPG::MapInfo === m
              m.scroll_x = 0
              m.scroll_y = 0
              m.expanded = true
            end
          end
        }
      rescue TypeError
        raise InvalidFormatedFile, %Q(Failed to load rvdata2 from "#{filename}")
      end
    end
  
  end
end

# rvdata2に変換する
class Rv2da::Converter::Composition
  extend Rv2da::Converter 
  class << self
    
    def extension
      ".rvdata2"
    end
    
    def target_extension
      ".json"
    end
    
    # @raise [InvalidFormatedFile]
    def save(filename, obj)
      begin
        File.open(filename, "wb") {|f|
          Marshal.dump(obj, f)
        }
      rescue TypeError
        raise InvalidFormatedFile, %Q(Failed to save rvdata2 to "#{filename}")
      end
    end
    
    private
    
    def inner_convert(filename, name)
      Rv2da::JsonObject::json_to_proper_object(load_json(filename), RPG::RootObject(name)::hash_key_converter)
    end

    # JSONファイルを読み込む
    # @return [Object]
    # @param [String] filename
    # @raise [InvalidFormatedFile]
    def load_json(filename)
      begin
        JSON.restore(File.read(filename, :encoding => Encoding::UTF_8))
      rescue JSON::ParserError
        raise InvalidFormatedFile, %Q(Failed to load json from "#{filename}")
      end
    end

  end
end


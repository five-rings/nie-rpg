=begin
デバッグ関連の便利機能
=end
module Debug::Utility
class << self

  def start_process(file)
    IO.popen(file, err: [:child, :out]) do |io|
      while log = io.gets
        ITEFU_DEBUG_OUTPUT_NOTICE log
      end
    end
  end
  
end
end

=begin
  診断情報
  デバッガに与える情報を収集するための機能  
=end
module Debug::Diagnosis
  
  # 有効にする
  def self.enable
    # @todo
    self.extend Implement
  end

private
  module Implement
    def self.extended(object)
      @dignosis = {}
    end
    
    def clear
      @diagnosis.clear
    end
    
    # 診断情報を定義する
    def define(*ids)
      key = ids.join("/")
      @diagnosis[key] ||= {}
    end
    
    # 診断情報を記録/更新する
    def store(id, value, *ids)
      key = ids.join("/")
      h = @diagnosis[key]
      h[id] = value if h
    end
    
    # 診断情報を取得する
    def fetch(id, *ids)
      key = ids.join("/")
      h = @diagnosis[key]
      h[id] if h
    end
  end

end
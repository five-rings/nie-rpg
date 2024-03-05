=begin
  Rgss3のデフォルト実装を拡張する
=end
class RPG::EquipItem
  attr_reader :extra_items      # 追加された強化アイテム
  alias :features_org :features
  alias :params_org :params

  ExtraItemData = Struct.new(:item, :count)

  def features
    update_extra_features unless @extra_features
    @extra_features
  end

  def params
    update_extra_params unless @extra_params
    @extra_params
  end

  # 追加アイテム分のみの能力値
  def extra_params(id)
    params[id] - params_org[id]
  end

  # 名前を変更する
  def change_name(name)
    self.name = name
  end

  # アイテムを装着する
  # @return [ExtraItemData] 今まで装着していたアイテムと個数
  def embed_extra_item(slot_index, item, count)
    @extra_items ||= []
    old = @extra_items[slot_index]
    @extra_items[slot_index] = ExtraItemData.new(item, count)
    update_extra_features
    update_extra_params
    old
  end

  def extra_item_embedded?
    @extra_items && @extra_items.any?
  end

  # アイテムを装着する（スロット未指定）
  # @note 既に同じアイテムを装着する場合は同じスロットに上書きする
  # @param [RPG::EquipItem] item 装着する強化アイテム
  # @param [NilClass|FixNum] count 指定しなかった場合は、現状に1足す
  def assign_extra_item(item, count = nil)
    slot_index = 0
    while embeded_item = embeded_extra_item(slot_index)
      # 同じ素材アイテムを装備していないか探す
      break if item == embeded_item.item
      slot_index += 1
    end
    count ||= embeded_item && embeded_item.count + 1 || 1
    embed_extra_item(slot_index, item, count)
  end

  def remove_extra_item(slot_index)
    if @extra_items
      old = @extra_items[slot_index]
      @extra_items[slot_index] = nil
      update_extra_features
      update_extra_params
      old
    end
  end

  # 装着中のアイテムと個数
  def embeded_extra_item(slot_index)
    @extra_items && @extra_items[slot_index]
  end

  # 装着中のアイテムをすべてはずす
  def clear_extra_items
    if @extra_items
      @extra_items.clear
      update_extra_features
      update_extra_params
    end
  end

  def update_extra_features
    unless @extra_items
      @extra_features = features_org
      return
    end
    @extra_features = @extra_items.each_with_object([].concat(features_org)) {|item_data, memo|
      item_data.count.times do
        memo.concat(item_data.item.features)
      end if item_data
    }
  end

  def update_extra_params
    unless @extra_items
      @extra_params = params_org
      return
    end
    @extra_params = params_org.map.with_index {|v, id|
      @extra_items.each do |item_data|
        v += item_data.item.params[id] * item_data.count if item_data
      end
      v
    }
  end

end


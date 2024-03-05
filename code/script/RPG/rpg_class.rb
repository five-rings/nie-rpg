=begin
  Rgss3のデフォルト実装を拡張する
=end
class RPG::Class
  alias :exp_for_level_org :exp_for_level

  def job_name=(param)
    hs = special_flag(:job_name)
    ps = param.split(",")
    hs[Integer(ps[0])] = ps[1]
  end

  def highjob_name(new_level, old_level, string = true)
    return unless hs = special_flag(:job_name)
    range = ((old_level+1)..new_level)
    name_lv = hs.keys.find_all {|lv|
      range.include?(lv)
    }.max
    if string
      hs[name_lv]
    else
      name_lv
    end
  end

  def skill_deleting_each(new_level, old_level)
    return unless rs = special_flag(:delete_skill)
    range = ((old_level+1)..new_level)
    rs.each do |lv, skills|
      yield(lv, skills) if range.include?(lv)
    end
  end

  def exp_for_level(level)
    Config::ExpTable.instance.exp_for_level(id, level) || exp_for_level_org(level)
  end

  alias :params_raw :params
  def params
    self
  end

  def [] (param_id, level)
    Config::Params.instance.params(id, param_id, level) || params_raw[param_id, level]
  end

end

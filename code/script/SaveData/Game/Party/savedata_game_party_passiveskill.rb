=begin
=end
module SaveData::Game::Party::PassiveSkill
  attr_reader :passive_skills
  attr_reader :passive_skill_point

  def initialize(*args)
    @passive_skills = []
    @passive_skill_point = 0
    super
  end
  
  # スキルポイントを増減させる
  def add_passive_skill_point(point = 1)
    @passive_skill_point += point
  end
  
  # スキルポイントをリセットする
  def reset_passive_skill_point(point)
    @passive_skill_point = point
  end

  # スキルを覚える
  def learn_passive_skill(skill_id, need_point = true)
    return if learnt_passive_skill?(skill_id)
    if need_point
      if @passive_skill_point > 0
        add_passive_skill_point(-1)
      else
        return nil
      end
    end
    @passive_skills.push(skill_id)
    skill_id
  end
  
  # スキルを忘れる
  def forget_passive_skill(skill_id, earn_point = false)
    deleted = @passive_skills.delete(skill_id)
    add_passive_skill_point(1) if deleted && earn_point
    deleted
  end
  
  # スキルをリセットする
  # @param [Fixnum] point リセット後のスキルポイントを指定する。しなかった場合、今まで覚えていたスキルの分だけ得る。
  def clear_passive_skills(point = nil)
    reset_passive_skill_point(point || @passive_skills.size)
    @passive_skills.clear
  end
  
  # 習得済みか？
  def learnt_passive_skill?(skill_id)
    @passive_skills.include?(skill_id)
  end

end

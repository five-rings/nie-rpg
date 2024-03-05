=begin
=end
class Map::Unit::Follower < Map::Unit::MapObject
  include Map::MapObject::Companion
  def default_priority; Map::Unit::Priority::PLAYER; end
  def passable?; true; end
  def move_speed; player.move_speed; end
  def walk_anime?; walk_anime && player.walk_anime?; end
  attr_accessor :actor_id

  RESUME_TARGETS = [
      :@next_command,
      :@commands,
      :@commanding,
      :@gathering,
  ] + (RESUME_TARGETS_APPEARANCE = [
      :@bush,
      :@transparent,
      :@opacity,
      :@blending_method,
  ]) + (RESUME_TARGETS_POS = [
      :@real_x,
      :@real_y,
      :@dest_x,
      :@dest_y,
      :@cell_x,
      :@cell_y,
      :@direction,
  ])
  def resume_targets; RESUME_TARGETS; end

  def on_suspend
=begin
    # 保存前に適用前の見た目に関するコマンドを処理しておく
    @commands.each do |command|
      if Command::ChangeValue == command
        do_command(command)
      end
    end
=end
    super
  end

  def apply_context(context, source)
    context.each do |key|
      instance_variable_set(key, source.instance_variable_get(key))
    end
  end

  # 対象の見た目を適用する
  def apply_appearance(lead_companion)
    apply_context(RESUME_TARGETS_APPEARANCE, lead_companion)
  end

  # 対象の位置を適用する
  def apply_position(lead_companion)
    apply_context(RESUME_TARGETS_POS, lead_companion)
  end

end

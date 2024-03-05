=begin
=end
module Audio
class << self

  @@bgm_scale = 1.0
  @@me_scale = 1.0
  @@bgs_scale = 1.0
  @@se_scale = 1.0

  def apply_volumes(volumes)
    @@bgm_scale = volumes[:bgm] / 100.0
    @@me_scale = volumes[:me] / 100.0
    @@bgs_scale = volumes[:bgs] / 100.0
    @@se_scale = volumes[:se] / 100.0
  end

  alias :bgm_play_org :bgm_play
  def bgm_play(filename, *args)
    args[0] = (args[0] * @@bgm_scale).to_i if args.size > 1
    bgm_play_org(filename, *args)
  end

  alias :me_play_org :me_play
  def me_play(filename, *args)
    args[0] = (args[0] * @@me_scale).to_i if args.size > 1
    me_play_org(filename, *args)
  end

  alias :bgs_play_org :bgs_play
  def bgs_play(filename, *args)
    args[0] = (args[0] * @@bgs_scale).to_i if args.size > 1
    bgs_play_org(filename, *args)
  end

  alias :se_play_org :se_play
  def se_play(filename, *args)
    args[0] = (args[0] * @@se_scale).to_i if args.size > 1
    se_play_org(filename, *args)
  end

end
end

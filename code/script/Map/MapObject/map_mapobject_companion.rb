=begin
  隊列の一員
=end
module Map::MapObject::Companion
  attr_reader :follower
  attr_reader :chara_name, :chara_index
  NORMAL_Z = Map::MapObject::Drawable::NORMAL_Z
  
  module Command
    # 指定方向に移動する
    Move = Struct.new(:direction)
    # 指定した座標に移動する
    Transfer = Struct.new(:x, :y, :warp_direction)
    # ジャンプする
    Jump = Struct.new(:direction, :offset_x, :offset_y, :frame)
    # 列の先頭に集合する
    Gather = :gather_command
    # 合成方法を変更する
    ChangeValue = Struct.new(:accessor, :value)
  end
  
  def initialize(*args)
    @commands = []
    super
  end
  
  def finalize
    remove_follower
    super
  end
  
  def update
    process_moving_commands unless disabled? || moving? || jumping?
    super
    @follower.update if @follower
  end

  def on_moved(*args)
    process_nonmoving_commands
    super
  end

  def on_unmoved(*args)
    process_nonmoving_commands
    super
  end
  
  def draw
    super
    @follower.draw if @follower
  end
  
  def update_scroll(ox, oy)
    super
    @follower.update_scroll(ox, oy) if @follower
  end
  
  # 現在のマップの情報を設定する
  def replace_to_new_map(map_instance, viewport)
    @follower.replace_to_new_map(map_instance, viewport) if @follower
    self.map_instance = map_instance
    if map_instance && map_instance.map_data.disable_dashing
      self.dash(false)
    end
    assign_viewport(viewport)
    # @note 本来であればこれでプレイヤーがイベントより上に来るが、イベントの遅延生成のため下になってしまっている
    recreate_sprite
  end

  # 後続の人員を追加する
  def add_follower(direction = nil)
    unless @follower
      @follower = Map::Unit::Follower.new(manager)
      @follower.direction = direction if direction
    end
    @follower
  end
  
  # 後続を切り離す
  # @note 切り離した後続に続く人員は全て破棄される
  def remove_follower
    return unless @follower
    @follower.finalize
    @follower = nil
  end

  # 後続する人員の数
  # @note リストを辿るので計算量がO(N)であることに注意
  # @param [Fixnum] i 数字をいくつからカウントしはじめるか
  def number_of_followers(i = 0)
    companion = self
    while companion = companion.follower
      i += 1
    end
    i
  end
  
  # 指定座標への移動をフックする
  def transfer(x, y, warp = false, command = nil, dir = self.direction)
    if command
      @next_command = command
    elsif @next_command.nil? || warp
      @next_command = Command::Transfer.new(x, y, dir)
    end
    @follower.add_moving_command(@next_command) if @follower && @next_command
    @next_command = nil
    super(x, y, warp)
  end
  
  # 指定方向への移動をフックする 
  def move(direction, command = nil)
    @next_command = command || Command::Move.new(direction)
    super(direction)
  end
  
  # ジャンプをフックする
  def jump(x, y, f = 10, command = nil)
    @next_command = command || Command::Jump.new(self.direction, x, y, f)
    super(x, y, f)
  end

  # 合成方法の変更をフックする
  def blending_method=(value)
    if self.blending_method != value
      @follower.add_command(Command::ChangeValue.new(:blending_method=, value)) if @follower
    end
    super
  end
  
  # 先頭へ集合する
  def gather
    add_moving_command(Command::Gather)
  end
  
  # @return [Boolean] 集合しようとしている最中か？
  def gathering?
    @gathering || @follower && @follower.gathering?
  end

  # 追従者を自分と同じ向きにする
  def orientate_follower
    if @follower
      unless map_instance.ladder_tile?(@follower.cell_x, @follower.cell_y)
        dir = Itefu::Rgss3::Definition::Direction.from_pos(@follower.cell_x, @follower.cell_y, self.cell_x, self.cell_y)
        dir = self.direction unless Itefu::Rgss3::Definition::Direction.valid?(dir)
        @follower.turn dir
      end
      @follower.orientate_follower
    end
  end

  # 移動コマンドを解釈し対応する処理を実行する
  def do_command(command)
    case command
    when Command::Move
      move(command.direction, command)
    when Command::Jump
      turn(command.direction)
      jump(command.offset_x, command.offset_y, command.frame, command)
    when Command::Transfer
      if command.warp_direction
        turn(command.warp_direction)
        transfer(command.x, command.y, true, command)
      else
        transfer(command.x, command.y, false, command)
      end
    when Command::Gather
      @follower.add_moving_command(command) if @follower
      @gathering = false
    when Command::ChangeValue
      self.send(command.accessor, command.value)
    end
  end
  
  # 移動コマンドを追加する
  def add_moving_command(command)
    if Command::Transfer === command && command.warp_direction
      @commands.clear
      @commanding = nil
      @next_command = nil
      turn(command.warp_direction)
      transfer(command.x, command.y, true)
    else
      @gathering = true if Command::Gather === command
      @commanding = command
    end
  end

  def add_command(command)
    @commands << command
  end

  # 移動コマンドを一つ実行する
  # @note 新しいコマンドが追加される際に一番古いコマンドを一つ実行する
  # @note 集合中のみは新しいコマンドがなくても順次処理していく
  def process_moving_commands
    return unless @commanding || @gathering

    # 移動系のコマンドが実行できるまで処理する
    begin
      command = @commands.shift
      do_command(command) if command
    end while Command::ChangeValue === command

    if @commanding
      @commands << @commanding
      @commanding = nil
    end
  end

  # 移動後に値を変更するだけのコマンドがあれば処理する
  def process_nonmoving_commands
    while Command::ChangeValue === @commands[0]
      command = @commands.shift
      do_command(command) if command
    end
  end

end

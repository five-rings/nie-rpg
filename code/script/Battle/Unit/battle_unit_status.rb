=begin
  プレイヤーのステータス表示
=end

class Battle::Unit::Status < Battle::Unit::Base
  def default_priority; Battle::Unit::Priority::STATUS; end

  def on_initialize(viewport)
    party = manager.party

    @view = manager
    @viewmodel = ViewModel.new(viewport)
    @viewmodel.actors.change(true) do |actors|
      party.member_size.times do |i|
        actors << ViewModel::Status.new.tap {|status|
          party.copy_actor_data(i, status, :face_name, :face_index, :hp, :mhp, :mp, :mmp)
        }
      end
    end

    @view.add_layout(:left, "battle/status", @viewmodel).tap {|c|
      c.add_callback(:imported) {
        party.member_size.times do |i|
          a = @view.play_animation(:"status#{i}", :in)
          if i == 0
            a.finisher { change_unit_state(Battle::Unit::State::OPENED) }
          end
        end
      }
    }
    @view.add_layout(:top, "battle/party_state", @viewmodel)
  end

  def on_unit_state_changed(old)
    case unit_state
    when Battle::Unit::State::STARTED
      @started = true
    end
  end

  def on_update
    party = manager.party
    party_states = @party_states ||= Hash.new(0)
    party_states.clear
    db_states = manager.database.states
    @viewmodel.actors.value.each.with_index do |status, i|
      status.hp = party.hp(i)
      status.mp = party.mp(i)
      status.mhp = party.mhp(i)
      status.mmp = party.mmp(i)
      if @started # @memo 入場演出中にステートを反映すると表示がズレるので演出完了に合わせて表示しはじめるようにしている
        # deep copy して値が変わったら更新する
        state_data = party.state_data(i)
        status.state_data = Marshal.load(Marshal.dump(state_data)) if status.state_data.value != state_data
        # party states
        state_data.each_key do |state_id|
          next unless state = db_states[state_id]
          if state.party_state?
            party_states[state_id] |= 1 << i
          end
        end
      end
    end

    # party states
    @viewmodel.party_states = Hash[party_states.sort] if @started
  end

  # 全てのステータスをアクティブにする
  def active_all
    @viewmodel.actors.value.each do |status|
      status.active = true
    end
  end

  # 一つのステータスをアクティブにする
  def active_only(user_index)
    @viewmodel.actors.value.each.with_index do |status, i|
      status.active = (user_index == i)
    end
  end

  def update_graphic
    party = manager.party
    @viewmodel.actors.value.each.with_index do |status, i|
      status.face_name = party.face_name(i)
      status.face_index = party.face_index(i)
    end
  end

  class ViewModel
    include Itefu::Layout::ViewModel
    attr_accessor :viewport
    attr_observable :actors
    attr_observable :party_states

    class Status
      include Itefu::Layout::ViewModel
      attr_observable :face_name
      attr_observable :face_index
      attr_observable :hp, :mhp
      attr_observable :mp, :mmp
      attr_observable :state_data
      attr_observable :active

      def initialize
        self.face_name = ""
        self.face_index = 0
        self.hp = self.mhp = 0
        self.mp = self.mmp = 0
        self.state_data = {}
        self.active = true
      end
    end

    def initialize(viewport)
      self.viewport = viewport
      self.actors = []
      self.party_states = {}
    end
  end

end


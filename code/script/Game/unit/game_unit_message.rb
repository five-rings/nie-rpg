=begin
  Map::Viewのメッセージウィンドウを操作する
=end
module Game::Unit::Message
  include Itefu::Utility::State::Context
  attr_accessor :choice_index_to_reset

  Event_Position = Itefu::Rgss3::Definition::Event::Message::Position
  Event_Background = Itefu::Rgss3::Definition::Event::Message::Background
  Layout_Alignment = Itefu::Layout::Definition::Alignment

  MessageData = Struct.new(:text, :face_name, :face_index, :background, :position)
  ChoiceData = Struct.new(:choices, :cancel_value, :callback)

  def initialize_controls(*args); raise Itefu::Exception::NotImplemented; end
  def finalize_controls; raise Itefu::Exception::NotImplemented; end
  def message_context; raise Itefu::Exception::NotImplemented; end
  def play_animation(control_name, anime_name); raise Itefu::Exception::NotImplemented; end
  def focus; raise Itefu::Exception::NotImplemented; end
  def control(name); raise Itefu::Exception::NotImplemented; end

  def on_initialize(*args)
    @closed = true
    @showing = false
    @text_ready = false
    @choice_index_to_reset = 0
    initialize_controls(*args)
    @message_queue = []
    change_state(State::Closed)
  end

  def on_finalize
    clear_state
    finalize_controls
  end

  def on_update
    update_state
  end

  def on_draw
    draw_state
  end

  # @return [Boolean] ウィンドウを閉じているか
  # @note 完全にウィンドウが閉じている状態のときのみtrueになる
  def window_closed?
    @closed
  end

  # @return [Boolean] メッセージ表示中か
  # @note ウィンドウを開き始めてからメッセージを送るまでtrueになる
  def showing?
    @showing
  end

  # @return [Boolean] 表示するテキストの準備ができたか
  # @note コントロールに割り当てられたテキストが変わると自動的に計算されるのでその処理が済んだかどうかをチェックするのに使用する
  def ready?
    @text_ready
  end


  # @return [Boolean] テキストを差し替え可能か
  # @note 表示位置などが同じで、メッセージを送った直後からウィンドウを閉じ始める間だけtrueになる
  def reassignable?(background, position)
    state == State::ToClose && @message &&
    background == @message.background &&
    position == @message.position
  end

  # メッセージウィンドウを表示する
  def show(message, face_name, face_index, background, position)
    message.split("\\p").each do |text|
      if state == State::Closed
        # ウィンドウ開始へ
        show_message(text, face_name, face_index, background, position)
        change_state(State::Opening)
      elsif state == State::ToClose
        # メッセージを更新して表示中へ戻る
        reassign_message(text, face_name, face_index, background, position)
        change_state(State::Showing)
      else
        # 予約する
        @message_queue << MessageData.new(text, face_name, face_index, background, position)
      end
    end
  end

  # @return [Boolean] 選択肢を表示中か
  # @note 選択肢を予約してから選択を行うまでtrueになる 
  def choices_showing?
    @choice.nil?.!
  end

  # 選択肢を開く
  def open_choices(choices, cancel_value, &callback)
    @choice = ChoiceData.new(choices, cancel_value, callback)
  end

  # 数値入力を開く
  def open_numeric_input(digit, &callback)
    @proc_numeric = callback
    if c = message_context
      c.digit = digit
    end
  end

  def numeric_input_showing?
    @proc_numeric.nil?.!
  end


private

  # ウィンドウを開きメッセージを表示する
  def show_message(text, face_name, face_index, background, position)
    context = message_context

    case position
    when Event_Position::TOP
      context.alignment = Layout_Alignment::TOP
    when Event_Position::CENTER
      context.alignment = Layout_Alignment::CENTER
    when Event_Position::BOTTOM
      context.alignment = Layout_Alignment::BOTTOM
    end

    context.face_name = face_name
    context.face_index = face_index
    context.background = background

    play_animation(:message_window, :in).finisher {
      if state_on_working? && c = message_context
        c.message = ""
        c.message = text
        change_state(State::Showing)
      end
    }
    play_animation(:message_sprite, :in) if background == Event_Background::DARK
    @text_ready = false
    @message = MessageData.new(text, face_name, face_index, background, position)
  end

  # 表示済みのメッセージを差し替える
  def reassign_message(text, face_name, face_index, background, position)
    context = message_context

    context.face_name = face_name
    context.face_index = face_index
    context.background = background
    context.message = ""
    context.message = text
    @text_ready = false
    @message = MessageData.new(text, face_name, face_index, background, position)
  end


  # メッセージ送りをした
  def message_decided(control, autofeed)
    if state == State::Showing
      change_state(State::ToClose)
    end
  end

  # 表示するテキスト情報が構築された
  def updated_drawing_info(control, text, drawing_info)
    @text_ready = true
  end

  # メッセージを表示し終わった
  def message_shown(control)
    if state == State::Showing
      case
      when choices_showing?
        change_state(State::WaitForChoice)
      when numeric_input_showing?
        change_state(State::WaitForNumericInput)
      end
    end
  end

  # 所持金の表示
  def commanded_to_show_budget(control)
    if control(:message_budget_window).openness != 0
      # 既に開いている場合は閉じる（トグル）
      play_animation(:message_budget_window, :out)
    else
      # 現在の所持金を表示する
      message_context.budget = Map::SaveData::GameData.party.money
      play_animation(:message_budget_window, :in)
    end
  end

  # 選択肢を選んだ
  def choices_decided(control, index, x, y)
    if state == State::WaitForChoice
      @choice.callback.call(index)
      if showing?
        change_state(State::ToClose)
      else
        change_state(State::Closed)
      end
    end
  end

  # 選択肢でキャンセルをした
  def choices_canceled(control, index)
    if state == State::WaitForChoice
      # キャンセル時にフォーカスが外れないようにする
      focus.push(control)
      if @choice.cancel_value < 0
        # キャンセル無効
      else
        @choice.callback.call(@choice.cancel_value)
        if showing?
          change_state(State::ToClose)
        else
          change_state(State::Closed)
        end
      end
    end
  end

  # 数値入力で決定した
  def numeric_decided(control, index, *args)
    if state == State::WaitForNumericInput
      @proc_numeric.call(control.unbox(control.number)) if @proc_numeric
      if showing?
        change_state(State::ToClose)
      else
        change_state(State::Closed)
      end
    end
  end

  # 数値入力の制御
  def operate_numeric(control, code, *args)
    case code
    when Itefu::Layout::Definition::Operation::CANCEL
      Sound.play_disabled_se
      nil
    else
      code
    end
  end


  module State
    # メッセージウィンドウ
    module Closed
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module Opening
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module Showing
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module ToClose
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    module Closing
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update
    end
    # 選択肢
    module WaitForChoice
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end
    # 数値入力
    module WaitForNumericInput
      extend Itefu::Utility::State::Callback::Simple
      define_callback :attach, :update, :detach
    end
  end

public

  # --------------------------------------------------
  # Closed

  def on_state_closed_attach
    @closed = true
  end

  def on_state_closed_update
    message = @message_queue.shift
    case
    when message
      show_message(*message.to_a)
      change_state(State::Opening)
    when choices_showing?
      change_state(State::WaitForChoice)
    when numeric_input_showing?
      change_state(State::WaitForNumericInput)
    end
  end

  # --------------------------------------------------
  # Opening

  def on_state_opening_attach
    @closed = false
    @showing = true
    if c = control(:message_text)
      c.reset_skipped_by_move
    end
  end

  def on_state_opening_update
    c = control(:message_text)
    focus.push(c) unless c.focus
  end

  # --------------------------------------------------
  # Showing

  def on_state_showing_attach
    # Openingを経由しない場合用
    @showing = true
  end

  def on_state_showing_update
  end

  # --------------------------------------------------
  # ToClose

  def on_state_to_close_attach
    @to_close = 0
    @showing = false
  end

  def on_state_to_close_update
    @to_close += 1
    if @to_close > 1
      change_state(State::Closing)
      return
    end
    message = @message_queue.shift
    if message
      reassign_message(*message.to_a)
      change_state(State::Showing)
    end
  end

  # --------------------------------------------------
  # Closing

  def on_state_closing_attach
    focus.pop
    message_context.message = ""
    play_animation(:message_window, :out).finisher {
      change_state(State::Closed) if state_on_working?
    }
    play_animation(:message_sprite, :out) if @message.background == Event_Background::DARK
    play_animation(:message_budget_window, :out) if control(:message_budget_window).openness != 0
    @message = nil
  end

  def on_state_closing_update
  end

  # --------------------------------------------------
  # WaitForChoice

  def on_state_wait_for_choice_attach
    message_context.choices.modify @choice.choices
    control(:message_choices).cursor_index = @choice_index_to_reset if @choice_index_to_reset

    if (c = control(:message_text)) && c.skipped_by_move
      anime_in = :in
    else
      anime_in = :in_wait
    end
    play_animation(:message_choices_window, anime_in).finisher {
      focus.push(control(:message_choices)) if state_on_working?
    }
  end

  def on_state_wait_for_choice_update
  end

  def on_state_wait_for_choice_detach
    @choice = nil
    focus.pop
    play_animation(:message_choices_window, :out).finisher {
      if context = message_context
        context.choices.modify [] unless @choice
      end
    }
  end

  # --------------------------------------------------
  # WaitForNumericInput

  def on_state_wait_for_numeric_input_attach
    c = control(:message_numeric_dial)
    c.number = 0
    play_animation(:message_numeric_window, :in).finisher {
      focus.push(c) if state_on_working?
    }
  end

  def on_state_wait_for_numeric_input_update
  end

  def on_state_wait_for_numeric_input_detach
    @proc_numeric = nil
    focus.pop
    play_animation(:message_numeric_window, :out)
  end


end

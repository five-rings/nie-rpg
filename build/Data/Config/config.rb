=begin
  外部設定ファイル
=end

config.screen_size(640, 480)
# config.locale = Itefu::Language::Locale::EN_US

config.nie_intimacy_love = 30 # トゥルーエンドに必要なニエとの親密さ
config.speed_rand = proc {|base|
  8 + (base*2/10)           # 行動計算の乱数幅
}
config.critical_rate = 1.5  # クリティカル時の係数
config.weak_rate = 1.5      # 弱点時の係数
config.block_threshold = 0.76 # 耐性演出を強くする閾値（25%カットしたらを意図しているが属性付与の1個指定でも+1%になる実装になっているのでその分を加味している）
config.phit_base = 107      # 物理命中率の基礎値
config.mhit_base = 100      # 術式命中率の基礎値
config.hate_in_dead = 30    # 戦闘不能時の狙われ上昇値
config.skill_id_enemy_uncontrolled = 59 # 敵混乱時の使用スキルID
config.battle_effect_actor = 0.7 # 戦闘中のエフェクトサイズ（味方に当たる場合）
config.battle_effect_enemy = 1.0 # 戦闘中のエフェクトサイズ（敵に当たる場合）

# 無効なステートかチェックする対象のid
config.immuned_states = [
  11,  # 毒
  23,  # 睡眠
  59,  # スタン
  62,  # 混乱
  85,  # 沈黙
  21,  # 痺れ
  53,  # 暗闇
  64,  # 呪い
  150, # 埋没（土）
  67,  # 氷結（氷）
  80,  # 溺水（水）
]


# ダメージ辺りのキラキラ個数を計算する
# @param [Fixnum] damage ダメージ値
config.battle_chiritori_count = proc {|damage|
  Itefu::Utility::Math.min(damage/200+1, 20)
  # 20 # for test
}

# ちりとりネズミのお宝演出
# @param [Fixnum] count キラキラを出す個数
# @param [Fixnum] damage ダメージ値
# @param [SceneGraph::MapObject] node 描画用ノード
config.battle_chiritori_anime = proc {|count, damage, node|
      # 表示タイミングのズレ値（フレーム数）
      t = rand(15)
      # 上昇幅
      h = h1 = rand(20) + 30
      # 横に散る幅
      x = 100 + count*10
      x = rand(x) - x/2
      # 縦に散る幅
      y = 20 + count*4
      y = rand(y) - y/2
      # 放物線の計算
      cy = lambda {|rate, s, e|
        if rate < 0.5
          r = rate/0.5
          h = h1
          hp = h - h * (r*2 - 1)**2
          (e - s) * r - hp
        elsif rate < 0.8
          h = h1/2
          r = (rate - 0.5)/0.3
          hp = h - h * (r*2 - 1)**2
          (e - s) * r - hp
        else
          h = h1/3
          r = (rate - 0.8)/0.2
          hp = h - h * (r*2 - 1)**2
          (e - s) * r - hp
          (e - s) # 3跳ね目を無視
        end
      }
      # 横座標の放物線
      cx = lambda {|rate, s, e|
        if rate < 0.8
          rate = rate / 0.8
          s + (e - s) * rate
        else
          e
        end
      }
      # 効果音
      se = proc {|anime, frame, trigger|
        # SEの鳴らし方
        # Itefu::Sound.play_seplay_se("SE名", 音量[0-100], ピッチ[50-150])
        # 合いそうな？SE
          # Coin
          # Hammer
          # Ice1
          # Saint5
          # Shop
          # Starlight
          # Up3

        case trigger[:frame]
        when t+30*0.5
          Itefu::Sound.play_se("Starlight", 100-count*2, 135)
        else
#          Itefu::Sound.play_se("Ice1", 50, 120)
        end
      }

      # -------------------------------------------
      # アニメデータ
      anime = Itefu::Animation::KeyFrame.new
      Curve = Itefu::Animation::KeyFrame::CurveFunctions
      # 表示非表示
      anime.add_key  0, :visibility, false, Curve::STEP_BEGIN
      anime.add_key  t, :visibility, true, Curve::STEP_END
      # 効果音
      anime.add_trigger t+30*0.5, &se
      anime.add_trigger t+30*0.8, &se
      # X座標
      anime.add_key    t, :pos_x, 0, cx
      anime.add_key 30+t, :pos_x, x
      # Y座標
      anime.add_key    t, :pos_y, 0, cy
      anime.add_key 30+t, :pos_y, y

      # 返り値
      anime
}


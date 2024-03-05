=begin
  エンカウント計算
=end
module Game::Encounter

  # エンカウント率にシグモイド曲線を使用
  module SimpleSigmoid
    def reset_encounter_calculation; end

    def calculate_encounter_rate(step, mu)
      i_scale = 5.0 / mu   # @magic 傾斜をなんとなく詰める

      rate = Itefu::Utility::Math.sigmoid((step - mu) * i_scale) * i_scale

      rate
    end
  end

  # 歩数ごとのエンカウント頻度の分布が釣鐘型になるようにする
  module BellCurve
    def reset_encounter_calculation
      @rate_here = 1.0
    end

    def calculate_encounter_rate(step, mu)
      i_scale = 5.0 / mu   # @magic 傾斜をなんとなく詰める

      # step-1歩までにエンカウントする確率
      prev_dist = Itefu::Utility::Math.sigmoid((step-1 - mu) * i_scale)
      # step歩までにエンカウントする確率
      dist = Itefu::Utility::Math.sigmoid((step - mu) * i_scale)
      # step-1歩までエンカウントしなかったときに,
      # ちょうどstep歩目でエンカウントする確率
      rate = (dist - prev_dist) / @rate_here
      # 歩数が無限大に近づくと確率が微小になりすぎるので
      # 1/muを下回らないようにする
      rate = Itefu::Utility::Math.max(rate, 1.0 / mu) if step > mu
      # 次回の計算用
      @rate_here = @rate_here - (dist - prev_dist)

      rate
    end
  end

  # 歩数ごとのエンカウント頻度の分布が釣鐘型になるようにする（頂点補正版）
  module BellCurveModified
    def reset_encounter_calculation
      @rate_here = 1.0
    end

    def calculate_encounter_rate(step, mu)
      i_scale = 5.0 / mu   # @magic 傾斜をなんとなく詰める
      mu_modified = Itefu::Utility::Math.max(1, mu - 0.5)

      # step-1歩までにエンカウントする確率
      prev_dist = Itefu::Utility::Math.sigmoid((step-1 - mu_modified) * i_scale)
      # step歩までにエンカウントする確率
      dist = Itefu::Utility::Math.sigmoid((step - mu_modified) * i_scale)

      # step-1歩までエンカウントしなかったときに,
      # ちょうどstep歩目でエンカウントする確率
      rate = (dist - prev_dist) / @rate_here
      # 歩数が無限大に近づくと確率が微小になりすぎるので
      # 1/muを下回らないようにする
      rate = Itefu::Utility::Math.max(rate, 1.0 / mu) if step > mu
      # 次回の計算用
      @rate_here = @rate_here - (dist - prev_dist)

      rate
    end
  end

end

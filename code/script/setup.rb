=begin
  一番最初に読み込まれる
=end

# RGSSResetが補足されなかった場合に終了するようにする
$rgss_reset ||= 0
if ($rgss_reset += 1) > 1
  exit 1
end

# module等の定義時のデバッグ機能
#ifdef :debug
$itefu_default_runlevel = 2
#else
$itefu_default_runlevel = 0
#endif


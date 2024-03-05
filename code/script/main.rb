=begin
  Entry Point
=end
def main(*args)
  
#ifdef :test
  # テストを実行する
  # Itefu::UnitTest::TestCase::default_auto_run = false
  # Itefu::Test::Utility.auto_run = true

  ITEFU_DEBUG_OUTPUT_NOTICE "Run-Mode: Test"
  Itefu::UnitTest::Runner.run
#else_ifdef :benchmark
  # ベンチマーク測定を実行する
  ITEFU_DEBUG_OUTPUT_NOTICE "Run-Mode: Benchmark"
  Itefu::Benchmark.run
#else
  # ゲームを実行する
  ITEFU_DEBUG_OUTPUT_NOTICE "Run-Mode: Application"
  Application.run
#endif
end

main(*ARGV)

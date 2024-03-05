=begin
  デバッグ関連のマクロ定義 
=end
#exclude

# Process
#ifdef :debug
#define :ITEFU_DEBUG_PROCESS, "::Debug::Utility.start_process"
#else
#define :ITEFU_DEBUG_PROCESS, :NOP_LINE
#endif

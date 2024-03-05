#pragma once

#include <functional>
#include "rvp_process.h"

namespace rvp {

	class MessageHook {
	public:
		explicit MessageHook();
		~MessageHook();

		struct Hook {
			enum TYPE {
				NONE,		//!< Do-Nothing
				SAVE,		//!< Save Command
				TEST_PLAY,	//!< Do Test-Play Command
				NUM,
			};
		};

		/**!
		 * functor to hook WndProc
		 */
		typedef std::function<void(HWND)> WindowHook;

		/**!
		 * @param [in] modulename without file extension
		 * @param [in] hookproc
		 * @param [in] windowhook
		 * @throw std::runtime_error
		 */
		void hook(const TCHAR * modulename, HOOKPROC hookproc, WindowHook windowhook);

		/**!
		 * 
		 */
		void unhook();

		/**!
		 * @return Hook-Handle
		 */
		HHOOK getHookHandle() const { return m_handleHook; }

		/**!
		 * Call it when to procress Window Message has finished.
		 */
		void on_post_window_processed(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

		/**!
		 * Call it when WM_CREATE has been received.
		 */
		void on_created_window(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

		/**!
		 * Call it when WM_COMMAND has been received.
		 */
		void on_commanded(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

		/**!
		 * Call it when you have received any WindowMessages.
		 */
		void on_unknown(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

	private:
		void on_created_main_window(HWND hWnd);
		void run_hook_script();

		process::Parallel m_Process;
		HHOOK m_handleHook;
		HWND m_handleMainWindow;
		WNDPROC m_WndProc;
		Hook::TYPE m_typePostProcNeeded;
		Hook::TYPE m_typeSelected;
		WindowHook m_functionWindowHook;
	};
}

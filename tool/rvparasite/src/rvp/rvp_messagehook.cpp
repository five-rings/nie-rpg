#include "rvp_messagehook.h"
#include "rvp_process.h"
#include <stdexcept>

namespace {
	const TCHAR TARGET_WINDOW[] = TEXT("RPGツクールVX Ace");

	namespace HookScript {
		enum TYPE {
			PRE_SAVE,
			POST_SAVE,
			PRE_TESTPLAY,
			POST_TESTPLAY,

			NUM,
		};
		const TCHAR * const Files[] = {
			TEXT("hooks\\pre-save.bat"),
			TEXT("hooks\\post-save.bat"),
			TEXT("hooks\\pre-testplay.bat"),
			TEXT("hooks\\post-testplay.bat"),
		};
	};

	namespace CommandID {
		enum TYPE {
			SAVE = 0xe103,
			TEST_PLAY = 0x17a3,
		};
	}
}

namespace rvp {

	MessageHook::MessageHook()
		: m_Process()
		, m_handleHook(NULL)
		, m_handleMainWindow(NULL)
		, m_WndProc(NULL)
		, m_typePostProcNeeded(Hook::NONE)
		, m_typeSelected(Hook::NONE)
		, m_functionWindowHook()
	{
		for (int i = 0; i < HookScript::NUM; ++i) {
			m_Process.add(i, HookScript::Files[i]);
		}
	}

	MessageHook::~MessageHook()
	{
	}


	void MessageHook::hook(const TCHAR * modulename, HOOKPROC hookproc, WindowHook windowhook)
	{
		if (m_handleHook != NULL) {
			throw std::runtime_error("Already Hooked");
		}

		const HHOOK handle = SetWindowsHookEx(WH_CALLWNDPROC, hookproc, GetModuleHandle(modulename), GetCurrentThreadId());
		if (handle == NULL) {
			throw std::runtime_error("Failed To Hook");
		}

		m_handleHook = handle;
		m_functionWindowHook = windowhook;
	}

	void MessageHook::unhook()
	{
		if (m_handleHook != NULL) {
			UnhookWindowsHookEx(m_handleHook);
			m_handleHook = NULL;
		}
	}


	void MessageHook::on_post_window_processed(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		const auto typeToProc = m_typePostProcNeeded;
		m_typePostProcNeeded = Hook::NONE;

		try {
			switch (typeToProc) {
			case Hook::SAVE:
				m_Process.requestToBoot(HookScript::POST_SAVE);
				// rvp::process::boot(HookScript::PostSave);
				break;
			case Hook::TEST_PLAY:
//				m_Process.requestToBoot(HookScript::POST_TESTPLAY);
				// rvp::process::boot(HookScript::PostTestPlay);
				break;
			}
		} catch (std::runtime_error &e) {
			notify_error(e.what(), m_handleMainWindow);
		}
	}

	void MessageHook::on_created_window(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		// main window
		if (GetParent(hWnd) == NULL) {
			const size_t len = RVP_ARRAY_LENGTH(TARGET_WINDOW);
			TCHAR buffer[len+1] = { NULL };
			GetWindowText(hWnd, buffer, len);

			if (wcsncmp(buffer, TARGET_WINDOW, len) == 0) {
				on_created_main_window(hWnd);
			}
		}
	}

	void MessageHook::on_created_main_window(HWND hWnd)
	{
		if (m_handleMainWindow == NULL) {
			m_functionWindowHook(hWnd);
		}
		m_handleMainWindow = hWnd;
	}

	void MessageHook::on_commanded(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		if (hWnd != NULL) {
			DEBUG_PRINT("%8x WM_COMMAND (%x, %x)\n", hWnd, wParam, lParam);
		}
		if ((hWnd != NULL) && (hWnd == m_handleMainWindow)) {
			const auto id = wParam & 0xFFFF;
			switch (id) {
			case CommandID::SAVE:
				DEBUG_PRINT("command save\n");
				m_typeSelected = Hook::SAVE;
				break;

			case CommandID::TEST_PLAY:
				DEBUG_PRINT("command testplay\n");
				m_typeSelected = Hook::TEST_PLAY;
				break;
			}
			run_hook_script();
		}
	}

	void MessageHook::on_unknown(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		if (hWnd != NULL) {

			switch (msg) {

			// I don't know what it means, but
			// it's always sent when I focused on a menu item or button.
			case 0x362:
				switch (wParam) {
				case 0xe001:
					// ignore
					break;

				default:
					if (m_typeSelected != Hook::NONE) {
						DEBUG_PRINT("select cancel\n");
					}
					m_typeSelected = Hook::NONE;
					break;

				case CommandID::SAVE:
					DEBUG_PRINT("select save\n");
					m_typeSelected = Hook::SAVE;
					break;

				case CommandID::TEST_PLAY:
					DEBUG_PRINT("select testplay\n");
					m_typeSelected = Hook::TEST_PLAY;
					break;
				}
				break;

			// I don't know what it means, but
			// it's always sent when I save.
			case 0x110a:
				if (wParam == 0x4) {
					run_hook_script();
				}
				break;

			// I don't know what it means, but
			// it's almost sent when I select a button or menu command
			// except save command.
			case 0x36b:
				{
					run_hook_script();
				}
				break;
			}
		}
#if 0	// for research
		if (hWnd != NULL) {
			switch (msg) {
			case WM_DESTROY:
			case WM_SETFOCUS:
			case WM_KILLFOCUS:
			case WM_WINDOWPOSCHANGING:
			case WM_WINDOWPOSCHANGED:
			case WM_NCPAINT:
			case WM_NCDESTROY:
			case WM_NCHITTEST:
			case WM_ACTIVATEAPP:
			case WM_SETCURSOR:
			case WM_ERASEBKGND:
			case WM_SETTEXT:
			case WM_GETTEXT:
			case WM_PAINT:
			case WM_CAPTURECHANGED:
			case WM_IME_SETCONTEXT:
			case WM_ENTERIDLE:
			case 0x287:
			case 0x36a:
			case 0x407:
				break;

			case WM_NOTIFY:
				DEBUG_PRINT("uk = WM_NOTIFY (0x%x, 0x%x)\n", msg, wParam, lParam);
				break;

			default:
				DEBUG_PRINT("uk = 0x%4x (0x%x, 0x%x) w:%d p:%d (%d)\n", msg, wParam, lParam, GetParent(hWnd), GetParent(GetParent(hWnd)), m_handleMainWindow);
				break;
			}
		}
#endif
	}


	void MessageHook::run_hook_script()
	{
		const auto typeToProc = m_typeSelected;
		m_typeSelected = Hook::NONE;

		if (typeToProc != Hook::NONE) {
			DEBUG_PRINT("decided (%d)...run script\n", typeToProc);
			m_typePostProcNeeded = typeToProc;
		}

		try {
			switch (typeToProc) {
			case Hook::SAVE:
				DEBUG_PRINT("-------------run save\n");
				m_Process.requestToBoot(HookScript::PRE_SAVE);
				// rvp::process::boot(HookScript::PreSave);
				break;
			case Hook::TEST_PLAY:
				DEBUG_PRINT("-------------run testplay\n");
				m_Process.requestToBoot(HookScript::PRE_TESTPLAY);
				// rvp::process::boot(HookScript::PreTestPlay);
				break;
			}
		} catch (std::runtime_error &e) {
			notify_error(e.what(), m_handleMainWindow);
		}
	}
}

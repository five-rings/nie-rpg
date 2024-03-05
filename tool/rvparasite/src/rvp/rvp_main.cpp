#include "rvp_main.h"
#include "rvp_messagehook.h"
#include <stdexcept>

namespace {

	static class Main * s_pMain = NULL;

	class Main {
	public:
		explicit Main(const TCHAR * modulename);
		~Main();

	private:
		static LRESULT CALLBACK HookProc(int nCode, WPARAM wParam, LPARAM lParam);
		static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

		rvp::MessageHook m_MessageHook;
		WNDPROC m_WndProc;
	};
}

namespace rvp {

	void start(const TCHAR *modulename)
	{
#ifdef RVP_DEBUG
		::AllocConsole();
		FILE *stream = NULL;
		freopen_s(&stream, "CON", "w", stdout);
#endif
		s_pMain = new Main(modulename);
	}

	void end()
	{
		safe_delete(s_pMain);
	}
}

namespace {

	Main::Main(const TCHAR * modulename)
		: m_MessageHook()
		, m_WndProc(NULL)
	{
		const auto windowhook = [=](HWND hWnd) -> void
			{
				m_WndProc = (WNDPROC)SetWindowLong(hWnd, GWL_WNDPROC, reinterpret_cast<LONG>(Main::WndProc));
			};

		try {
			m_MessageHook.hook(modulename, (HOOKPROC)Main::HookProc, windowhook);
		} catch (std::runtime_error &e) {
			rvp::notify_error(e.what());
		}
	}

	Main::~Main()
	{
		m_MessageHook.unhook();
	}


	LRESULT CALLBACK Main::HookProc(int nCode, WPARAM wParam, LPARAM lParam)
	{
		if (nCode == HC_ACTION) {
			if ((wParam == NULL) && (lParam != NULL)) {
				const CWPSTRUCT * const pcwp = reinterpret_cast<CWPSTRUCT *>(lParam);
				switch (pcwp->message) {
				default:
					if (s_pMain != NULL) {
						s_pMain->m_MessageHook.on_unknown(pcwp->hwnd, pcwp->message, pcwp->wParam, pcwp->lParam);
					}
					break;

				case WM_CREATE:
					if (s_pMain != NULL) {
						s_pMain->m_MessageHook.on_created_window(pcwp->hwnd, pcwp->message, pcwp->wParam, pcwp->lParam);
					}
					break;

				case WM_COMMAND:
					if (s_pMain != NULL) {
						s_pMain->m_MessageHook.on_commanded(pcwp->hwnd, pcwp->message, pcwp->wParam, pcwp->lParam);
					}
				}
			}
		}

		const HHOOK handle = s_pMain ? s_pMain->m_MessageHook.getHookHandle() : NULL;
		return CallNextHookEx(handle, nCode, wParam, lParam);
	}

	LRESULT CALLBACK Main::WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		if (s_pMain == NULL) {
			return DefWindowProc(hWnd, msg, wParam, lParam);
		}

		const LRESULT result = CallWindowProc(s_pMain->m_WndProc, hWnd, msg, wParam, lParam);
		s_pMain->m_MessageHook.on_post_window_processed(hWnd, msg, wParam, lParam);

		return result;
	}
}

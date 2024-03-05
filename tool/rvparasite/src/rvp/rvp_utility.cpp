#include "rvp_utility.h"

namespace rvp {

	void notify_error(const char *message, HWND hWnd)
	{
		::MessageBoxA(hWnd, message, "rvp: Error", MB_OK);
	}

	void notify_error(const wchar_t *message, HWND hWnd)
	{
		::MessageBoxW(hWnd, message, L"rvp: Error", MB_OK);
	}

}


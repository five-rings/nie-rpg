#pragma once

#define RVP_ARRAY_LENGTH(a)	(sizeof(a)/sizeof(a[0]))

#if defined(_DEBUG) || defined(DEBUG)
#define RVP_DEBUG
#endif

#ifdef RVP_DEBUG
#define DEBUG_PRINT(...)  printf(__VA_ARGS__)
#else
#define DEBUG_PRINT(...)
#endif

namespace rvp {

	template<typename T>
	void safe_delete(T &p)
	{
		if (p != nullptr) {
			delete p;
			p = nullptr;
		}
	}

	template<typename T>
	void safe_delete(const T &p)
	{
		if (p != nullptr) {
			delete p;
		}
	}

	template<typename T>
	void safe_delete_array(T &p)
	{
		if (p != nullptr) {
			delete []p;
			p = nullptr;
		}
	}

	template<typename T>
	void safe_delete_array(const T &p)
	{
		if (p != nullptr) {
			delete []p;
		}
	}

	/**!
	 * Shows Error Message
	 */
	void notify_error(const char *message, HWND hWnd = NULL);

	/**!
	 * Shows Error Message
	 */
	void notify_error(const wchar_t *message, HWND hWnd = NULL);

}

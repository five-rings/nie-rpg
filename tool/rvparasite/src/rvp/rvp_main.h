#pragma once

namespace rvp {

	/*!
	 * Call it when this dll is loaded.
	 * @param [in] modulename without filename extension
	 */
#if defined(UNICODE) || defined(_UNICODE)
	void start(const wchar_t *modulename);
#else
	void start(const char *modulename);
#endif

	/*!
	 * Call when process is shut down.
	 */
	void end();
}

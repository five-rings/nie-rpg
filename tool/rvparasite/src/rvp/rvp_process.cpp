#include "rvp_process.h"
#include <stdexcept>
#include <algorithm>
#include <windows.h>

namespace rvp {
namespace process {

	DWORD boot(const TCHAR *filename, TCHAR *commandLineArguments)
	{
		STARTUPINFO startupinfo = { 0 };
		GetStartupInfo(&startupinfo);
#ifndef RVP_DEBUG
		startupinfo.wShowWindow = SW_HIDE;
#endif
		PROCESS_INFORMATION processinfo = { 0 };

		{
			const BOOL result = CreateProcess(filename, commandLineArguments, NULL, NULL, TRUE, 0, NULL, NULL, &startupinfo, &processinfo);
			if (result != TRUE) {
				throw std::runtime_error("Failed to create process");
			}
			CloseHandle(processinfo.hThread);
		}

		WaitForSingleObject(processinfo.hProcess, INFINITE);

		DWORD exitcode = 0;
		{
			const BOOL result = GetExitCodeProcess(processinfo.hProcess, &exitcode);
			CloseHandle(processinfo.hProcess);
			if (result != TRUE) {
				throw std::runtime_error("Failed to get exit code");
			}
		}

		return exitcode;
	}

	namespace  {
		DWORD WINAPI threadfunc(LPVOID vdParam)
		{
			auto process = reinterpret_cast<Parallel *>(vdParam);

			while (process && process->isRunning()) {
				process->boot();
				::Sleep(1);
			}

			ExitThread(0);
		}
	}

	Parallel::Parallel()
		: m_CriticalSection()
		, m_isRunning(true)
	{
		InitializeCriticalSection(&m_CriticalSection);
		m_hThread = CreateThread(NULL, 0, threadfunc, (LPVOID)this, 0, NULL);
	}

	Parallel::~Parallel()
	{
		m_isRunning = false;
		if (m_hThread != NULL) {
			WaitForSingleObject(m_hThread, INFINITE);
		}
		DeleteCriticalSection(&m_CriticalSection);
	}

	bool Parallel::add(int key, const TCHAR *filename, TCHAR *commandLineArguments)
	{
		auto p = new(std::nothrow) Command();
		if (p == nullptr) {
			return false;
		}
		p->filename = filename;
		p->commandLineArguments = commandLineArguments;

		EnterCriticalSection(&m_CriticalSection);
		{
			auto itr = m_Commands.find(key);
			if (itr != m_Commands.end()) {
				rvp::safe_delete(itr->second);
			}
			m_Commands[key] = p;
		}
		LeaveCriticalSection(&m_CriticalSection);

		return true;
	}

	void Parallel::requestToBoot(int key)
	{
		EnterCriticalSection(&m_CriticalSection);
		m_Requests[key] = true;
		LeaveCriticalSection(&m_CriticalSection);
	}

	void Parallel::boot()
	{
		const TCHAR *filename = NULL;
		TCHAR *commandLineArguments = NULL;

		EnterCriticalSection(&m_CriticalSection);
		{
			const auto itr = std::find_if(m_Requests.begin(), m_Requests.end(), [](Requests::value_type &v) -> bool {
				return v.second;
			});
			if (itr != m_Requests.end()) {
				itr->second = false;	// processed

				auto itrRequested = m_Commands.find(itr->first);
				if (itrRequested != m_Commands.end() && itrRequested->second) {
					filename = itrRequested->second->filename;
					commandLineArguments = itrRequested->second->commandLineArguments;
				}
			}
		}
		LeaveCriticalSection(&m_CriticalSection);

		if (filename && commandLineArguments) {
			try {
				rvp::process::boot(filename, commandLineArguments);
			} catch (std::runtime_error &e) {
				notify_error(e.what(), NULL);
			}
		}
	}
}
}

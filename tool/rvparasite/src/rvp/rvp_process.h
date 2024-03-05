#pragma once

#include <map>

namespace rvp {
namespace process {

	/*!
	 * @param [in] filename
	 * @param [in] commandLineArguments
	 * @return exit-code
	 * @throw std::runtime_error
	 */
	DWORD boot(const TCHAR *filename, TCHAR *commandLineArguments = TEXT(""));

	/// プロセスの実行を並行して行う
	class Parallel {
	public:
		explicit Parallel();
		~Parallel();

		bool add(int key, const TCHAR *filename, TCHAR *commandLineArguments = TEXT(""));
		void requestToBoot(int key);

		bool isRunning() const;
		void boot();

	private:

		struct Command {
			const TCHAR *filename;
			TCHAR *commandLineArguments;
		};
		typedef std::map<int, Command*> Commands;

		typedef std::map<int, bool> Requests;

		CRITICAL_SECTION m_CriticalSection;
		Commands m_Commands;
		Requests m_Requests;
		HANDLE m_hThread;
		bool m_isRunning;
	};

	inline bool Parallel::isRunning() const
	{
		return m_isRunning;
	}
}
}

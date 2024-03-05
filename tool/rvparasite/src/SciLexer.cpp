#include "rvp/rvp_main.h"

#define MY_MODULE_NAME	TEXT("SciLexer")
#define TARGET_DLL		(MY_MODULE_NAME TEXT("/") MY_MODULE_NAME TEXT(".dll"))

namespace {
	FARPROC s_pScintilla_DirectFunction = NULL;
	HINSTANCE handleOriginalLibrary = NULL;
}

extern "C" {
__declspec(dllexport) void WINAPI Scintilla_DirectFunction(void*,void*,void*,void*) { _asm{ jmp s_pScintilla_DirectFunction } }
}

BOOL APIENTRY DllMain(HANDLE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
	switch(fdwReason) {
	default:
		break;

	case DLL_PROCESS_ATTACH:
		rvp::start(MY_MODULE_NAME);

		handleOriginalLibrary = LoadLibrary(TARGET_DLL);
		if(handleOriginalLibrary == NULL) {
			return FALSE;
		}
		s_pScintilla_DirectFunction = GetProcAddress(handleOriginalLibrary, "Scintilla_DirectFunction");
		break;

	case DLL_THREAD_ATTACH:
		break;

	case DLL_THREAD_DETACH:
		break;

	case DLL_PROCESS_DETACH:
		rvp::end();

		if (handleOriginalLibrary != NULL) {
			FreeLibrary(handleOriginalLibrary);
		}
		break;
	}

	return TRUE;
}

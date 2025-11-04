#ifdef _WIN32

#include "CFileSystemWindows.h"


static int GetFileInformationByNameFuncPtrInitialized = FALSE;
static GetFileInformationByNameFuncPtrType GetFileInformationByNameFuncPtrCache = NULL;


GetFileInformationByNameFuncPtrType getGetFileInformationByNameFuncPtr() {

    if (GetFileInformationByNameFuncPtrCache != NULL) {
        return GetFileInformationByNameFuncPtrCache;
    }
    if (GetFileInformationByNameFuncPtrInitialized) { return NULL; }

    HMODULE hModule = LoadLibraryW(L"kernel32.dll");
    if (hModule == NULL) { 
        GetFileInformationByNameFuncPtrInitialized = TRUE;
        return NULL; 
    }

    GetFileInformationByNameFuncPtrType funcPtr = (GetFileInformationByNameFuncPtrType)GetProcAddress(hModule,"GetFileInformationByName");

    if (funcPtr == NULL) {
        GetFileInformationByNameFuncPtrInitialized = TRUE;
        FreeLibrary(hModule);
        return NULL;
    }

    GetFileInformationByNameFuncPtrCache = funcPtr;
    GetFileInformationByNameFuncPtrInitialized = TRUE;

    return GetFileInformationByNameFuncPtrCache;

}

#endif 
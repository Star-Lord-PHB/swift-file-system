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



const ACCESS_MASK _FILE_GENERIC_READ = FILE_GENERIC_READ;
const ACCESS_MASK _FILE_GENERIC_WRITE = FILE_GENERIC_WRITE;
const ACCESS_MASK _FILE_GENERIC_EXECUTE = FILE_GENERIC_EXECUTE;
const ACCESS_MASK _FILE_ALL_ACCESS = FILE_ALL_ACCESS;

#endif 
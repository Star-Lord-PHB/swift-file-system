#ifdef _WIN32

#include "CFileSystemWindows.h"
#include <winternl.h>


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



HANDLE ReOpenDir(HANDLE hDirectory) {

    // An empty name relative to `hDirectory` resolves to the directory itself.
    UNICODE_STRING emptyName;
    RtlInitUnicodeString(&emptyName, L"");

    OBJECT_ATTRIBUTES attributes;
    InitializeObjectAttributes(&attributes, &emptyName, 0, hDirectory, NULL);

    IO_STATUS_BLOCK ioStatus;
    HANDLE hReopened = INVALID_HANDLE_VALUE;

    NTSTATUS status = NtOpenFile(
        &hReopened,
        FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
        &attributes,
        &ioStatus,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        FILE_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT | FILE_OPEN_FOR_BACKUP_INTENT
    );

    if (status < 0) {
        SetLastError(RtlNtStatusToDosError(status));
        return INVALID_HANDLE_VALUE;
    }

    return hReopened;

}

#endif 

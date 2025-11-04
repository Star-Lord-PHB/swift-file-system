#ifdef _WIN32

#include <windows.h>

inline DWORD makeLanguageIdentifier(USHORT primary, USHORT sub) {
    return MAKELANGID(primary, sub);
}

inline SID_IDENTIFIER_AUTHORITY getSecurityWorldSidAuthority() {
    SID_IDENTIFIER_AUTHORITY authority = SECURITY_WORLD_SID_AUTHORITY;
    return authority;
}


typedef BOOL(WINAPI* GetFileInformationByNameFuncPtrType)(
    PCWSTR FileName,
    FILE_INFO_BY_NAME_CLASS FileInformationClass,
    PVOID FileInfoBuffer,
    ULONG FileInfoBufferSize
);


GetFileInformationByNameFuncPtrType getGetFileInformationByNameFuncPtr();

#endif
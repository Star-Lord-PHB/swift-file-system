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


/// Copied from Microsoft documentation: https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_data_buffer
typedef struct {
    ULONG  ReparseTag;
    USHORT ReparseDataLength;
    USHORT Reserved;
    union {
        struct {
            USHORT SubstituteNameOffset;
            USHORT SubstituteNameLength;
            USHORT PrintNameOffset;
            USHORT PrintNameLength;
            ULONG  Flags;
            WCHAR  PathBuffer[1];
        } SymbolicLinkReparseBuffer;
        struct {
            USHORT SubstituteNameOffset;
            USHORT SubstituteNameLength;
            USHORT PrintNameOffset;
            USHORT PrintNameLength;
            WCHAR  PathBuffer[1];
        } MountPointReparseBuffer;
        struct {
            UCHAR DataBuffer[1];
        } GenericReparseBuffer;
    } DUMMYUNIONNAME;
} MAPPED_REPARSE_DATA_BUFFER;

inline WCHAR* getReparseDataBufferSymbolicLinkPathBuffer(MAPPED_REPARSE_DATA_BUFFER* buffer) {
    return buffer->SymbolicLinkReparseBuffer.PathBuffer;
}

#endif
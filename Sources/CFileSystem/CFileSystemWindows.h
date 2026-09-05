#ifdef _WIN32

#include <windows.h>

inline DWORD makeLanguageIdentifier(USHORT primary, USHORT sub) {
    return MAKELANGID(primary, sub);
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


extern const ACCESS_MASK _FILE_GENERIC_READ;
extern const ACCESS_MASK _FILE_GENERIC_WRITE;
extern const ACCESS_MASK _FILE_GENERIC_EXECUTE;
extern const ACCESS_MASK _FILE_ALL_ACCESS;


/// Reopens an open directory handle as a new file object: the Windows counterpart of `openat(fd, ".")`.
///
/// `ReOpenFile` cannot do this. It always opens with `FILE_NON_DIRECTORY_FILE`, so on a directory it fails
/// with `ERROR_ACCESS_DENIED`, the Win32 mapping of `STATUS_FILE_IS_A_DIRECTORY`. This function instead
/// opens an empty name relative to `hDirectory` through `NtOpenFile`, which names the directory itself:
/// it keeps working after the directory was renamed, and the returned handle owns an independent
/// directory-enumeration cursor (a `DuplicateHandle` copy would share the original's).
///
/// The new handle is synchronous and non-inheritable, opened for
/// `FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES | SYNCHRONIZE` (enough for directory enumeration and the
/// attribute queries behind `type()` / `fileInfo()`, which fail with `ERROR_ACCESS_DENIED` without
/// `FILE_READ_ATTRIBUTES`) with full sharing and backup intent (the equivalent of
/// `FILE_FLAG_BACKUP_SEMANTICS`). A fresh access check runs against the directory's current DACL. On
/// failure the function returns
/// `INVALID_HANDLE_VALUE` and sets the last error to the Win32 code of the `NTSTATUS`, e.g.
/// `ERROR_ACCESS_DENIED`, `ERROR_DIRECTORY` when `hDirectory` is not a directory, or
/// `ERROR_INVALID_HANDLE`.
HANDLE ReOpenDir(HANDLE hDirectory);

#endif
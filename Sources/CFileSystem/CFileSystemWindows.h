#ifdef _WIN32

#include <windows.h>

inline DWORD makeLanguageIdentifier(USHORT primary, USHORT sub) {
    return MAKELANGID(primary, sub);
}


// Copied from <minwinbase.h> and <winnt.h> of Windows SDK 10.0.26100, which declare them only for
// NTDDI_VERSION >= NTDDI_WIN11_ZN
#if !defined(NTDDI_WIN11_ZN) || NTDDI_VERSION < NTDDI_WIN11_ZN
typedef enum _FILE_INFO_BY_NAME_CLASS {
    FileStatByNameInfo,
    FileStatLxByNameInfo,
    FileCaseSensitiveByNameInfo,
    FileStatBasicByNameInfo,
    MaximumFileInfoByNameClass
} FILE_INFO_BY_NAME_CLASS, *PFILE_INFO_BY_NAME_CLASS;

typedef struct _FILE_STAT_BASIC_INFORMATION {
    LARGE_INTEGER FileId;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER AllocationSize;
    LARGE_INTEGER EndOfFile;
    DWORD FileAttributes;
    DWORD ReparseTag;
    DWORD NumberOfLinks;
    DWORD DeviceType;
    DWORD DeviceCharacteristics;
    DWORD Reserved;
    LARGE_INTEGER VolumeSerialNumber;
    FILE_ID_128 FileId128;
} FILE_STAT_BASIC_INFORMATION, *PFILE_STAT_BASIC_INFORMATION;
#endif

// Copied from <winnt.h> of Windows SDK 10.0.26100, which declares it regardless of NTDDI_VERSION
#ifndef NTDDI_WIN11_ZN
typedef struct _FILE_STAT_INFORMATION {
    LARGE_INTEGER FileId;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER AllocationSize;
    LARGE_INTEGER EndOfFile;
    DWORD FileAttributes;
    DWORD ReparseTag;
    DWORD NumberOfLinks;
    ACCESS_MASK EffectiveAccess;
} FILE_STAT_INFORMATION, *PFILE_STAT_INFORMATION;
#endif


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


// Copied from <winternl.h>
#define FILE_DIRECTORY_FILE                     0x00000001
#define FILE_SYNCHRONOUS_IO_NONALERT            0x00000020
#define FILE_NON_DIRECTORY_FILE                 0x00000040
#define FILE_OPEN_FOR_BACKUP_INTENT             0x00004000


/// Reopens an open file or directory handle as a new file object with its own access rights: the Windows
/// counterpart of `openat(fd, ".")` for directories and of a per-call `ReOpenFile` for files.
///
/// `ReOpenFile` cannot serve directories. It always opens with `FILE_NON_DIRECTORY_FILE`, so on a directory it
/// fails with `ERROR_ACCESS_DENIED`, the Win32 mapping of `STATUS_FILE_IS_A_DIRECTORY`. This function instead
/// opens an empty name relative to `handle` through `NtOpenFile`, which names the object itself: it keeps
/// working after the item was renamed, and a directory reopened this way owns an independent enumeration
/// cursor (a `DuplicateHandle` copy would share the original's, and `DuplicateHandle` can never widen the
/// rights of a file handle).
///
/// `DesiredAccess` is requested exactly as given: unlike `CreateFileW`, nothing adds `SYNCHRONIZE` or
/// `FILE_READ_ATTRIBUTES` behind the caller's back. `OpenOptions` are the `NtOpenFile` open options:
/// `FILE_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT | FILE_OPEN_FOR_BACKUP_INTENT` for the directory
/// listing reopen (a synchronous file object, so the enumeration behind `GetFileInformationByHandleEx` never
/// sees `STATUS_PENDING`), 0 for a metadata reopen. `FILE_SYNCHRONOUS_IO_*` requires `SYNCHRONIZE` in
/// `DesiredAccess`. The new handle is non-inheritable and opened with full sharing. A fresh access check
/// runs against the object's current DACL. On failure the function returns `INVALID_HANDLE_VALUE` and sets
/// the last error to the Win32 code of the `NTSTATUS`, e.g. `ERROR_ACCESS_DENIED`, `ERROR_DIRECTORY` when
/// `FILE_DIRECTORY_FILE` is given for a non-directory, or `ERROR_INVALID_HANDLE`.
HANDLE ReOpenHandle(HANDLE handle, ACCESS_MASK DesiredAccess, ULONG OpenOptions);

#endif

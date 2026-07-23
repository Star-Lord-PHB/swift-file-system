#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemTestSupport {

    struct WindowsBasicInfo: Equatable {

        let creationTime: Int64
        let accessTime: Int64
        let modificationTime: Int64
        let changeTime: Int64
        let attributes: DWORD

    }


    static func captureWindowsBasicInfo(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> WindowsBasicInfo {
        let noFollowFlag = followSymlink
            ? DWORD(0)
            : DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | noFollowFlag
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(FILE_READ_ATTRIBUTES),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                openFlags,
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        var info = FILE_BASIC_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileBasicInfo,
                &info,
                DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            ),
            sourceLocation: sourceLocation
        )

        return .init(
            creationTime: info.CreationTime.QuadPart,
            accessTime: info.LastAccessTime.QuadPart,
            modificationTime: info.LastWriteTime.QuadPart,
            changeTime: info.ChangeTime.QuadPart,
            attributes: info.FileAttributes
        )
    }


    static func setNativeWindowsAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let success = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, attributes.rawValue)
        }
        try #require(success, sourceLocation: sourceLocation)
    }

}

#endif

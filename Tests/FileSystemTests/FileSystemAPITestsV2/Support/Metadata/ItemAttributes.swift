import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#endif



extension FileSystemTestSupport.ItemMetadata {

    struct Attributes: Equatable, Sendable {

        let values: PlatformFileAttributes
        let supported: PlatformFileAttributes

    }


    static func captureAttributes(
        at path: FilePath,
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Attributes {
        #if canImport(WinSDK)
        try captureWindowsAttributes(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )
        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let metadata = try Stat(path, followTargetSymlink: followSymlink)
        return .init(
            values: .init(rawValue: metadata.flags.rawValue),
            supported: .all
        )
        #else
        var metadata = StatCompat()
        let flags = followSymlink ? CInt(0) : CInt(AT_SYMLINK_NOFOLLOW)
        let result = path.withPlatformString { pathPointer in
            systemStatCompat(pathPointer, flags, &metadata)
        }
        try #require(result == 0, sourceLocation: sourceLocation)
        return .init(
            values: .init(rawValue: metadata.st_attributes),
            supported: .init(rawValue: metadata.st_attributes_mask)
        )
        #endif
    }

}



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata {

    private static func captureWindowsAttributes(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> Attributes {
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
        try #require(
            handle != INVALID_HANDLE_VALUE,
            sourceLocation: sourceLocation
        )
        defer { CloseHandle(handle) }

        var metadata = FILE_BASIC_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileBasicInfo,
                &metadata,
                DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            ),
            sourceLocation: sourceLocation
        )

        return .init(
            values: .init(rawValue: metadata.FileAttributes),
            supported: .all
        )
    }

}
#endif

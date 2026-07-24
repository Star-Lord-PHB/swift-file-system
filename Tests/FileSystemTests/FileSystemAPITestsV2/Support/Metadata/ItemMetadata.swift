import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



/// Independently observed metadata for one filesystem item.
///
/// This type contains only metadata that the test support can observe reliably
/// enough to provide an independent assertion path for `FileInfo` APIs.
extension FileSystemTestSupport {

    struct ItemMetadata: Equatable, Sendable {

        let type: FileAttributeType
        let size: UInt64
        let identifier: FileIdentifier
        let attributes: Attributes
        let security: Security
        let times: Times


        static func capture(
            at path: FilePath,
            followSymlink: Bool = false,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws -> ItemMetadata {
            let url = followSymlink
                ? URL(filePath: path.string).resolvingSymlinksInPath()
                : URL(filePath: path.string)
            let fileManagerAttributes = try FileManager.default.attributesOfItem(
                atPath: url.path
            )

            let foundationType = try #require(
                fileManagerAttributes[.type] as? FileAttributeType,
                sourceLocation: sourceLocation
            )
            let size = try #require(
                fileManagerAttributes[.size] as? NSNumber,
                sourceLocation: sourceLocation
            )
            let identifier = try captureIdentifier(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )
            let attributes = try captureAttributes(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )
            let security = try captureSecurity(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )
            let times = try Times.capture(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )

            return .init(
                type: foundationType,
                size: size.uint64Value,
                identifier: identifier,
                attributes: attributes,
                security: security,
                times: times
            )
        }

    }

}



extension FileSystemTestSupport.ItemMetadata {

    struct Times: Equatable, Sendable {

        let access: Timestamp
        let modification: Timestamp
        let statusChange: Timestamp
        let creation: Timestamp?


        static func capture(
            at path: FilePath,
            followSymlink: Bool = false,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws -> Times {
            #if canImport(WinSDK)
            try captureWindowsTimes(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )
            #else
            try capturePOSIXTimes(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )
            #endif
        }

    }

}



#if !canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Times {

    private static func capturePOSIXTimes(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> Self {
        let metadata = try Stat(path, followTargetSymlink: followSymlink)

        return .init(
            access: .init(platformTime: metadata.st_atim),
            modification: .init(platformTime: metadata.st_mtim),
            statusChange: .init(platformTime: metadata.st_ctim),
            creation: try creationTimestamp(
                at: path,
                followSymlink: followSymlink,
                metadata: metadata,
                sourceLocation: sourceLocation
            )
        )
    }


    private static func creationTimestamp(
        at path: FilePath,
        followSymlink: Bool,
        metadata: Stat,
        sourceLocation: SourceLocation
    ) throws -> FileSystemTestSupport.ItemMetadata.Timestamp? {
        #if canImport(Darwin) || os(FreeBSD)
        .init(platformTime: metadata.st_birthtim)
        #elseif canImport(Glibc) || canImport(Musl)
        try linuxCreationTimestamp(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )
        #elseif os(OpenBSD)
        nil
        #else
        nil
        #endif
    }


    #if canImport(Glibc) || canImport(Musl)
    private static func linuxCreationTimestamp(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> FileSystemTestSupport.ItemMetadata.Timestamp? {
        var metadata = StatCompat()
        let flags = followSymlink ? CInt(0) : CInt(AT_SYMLINK_NOFOLLOW)
        let result = path.withPlatformString { pathPointer in
            systemStatCompat(pathPointer, flags, &metadata)
        }
        try #require(result == 0, sourceLocation: sourceLocation)
        guard metadata.has_btime != 0 else { return nil }
        return .init(platformTime: metadata.st_btim)
    }
    #endif

}
#endif



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Times {

    private static func captureWindowsTimes(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> Self {
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
            access: .init(platformTime: metadata.LastAccessTime),
            modification: .init(platformTime: metadata.LastWriteTime),
            statusChange: .init(platformTime: metadata.ChangeTime),
            creation: .init(platformTime: metadata.CreationTime)
        )
    }

}
#endif

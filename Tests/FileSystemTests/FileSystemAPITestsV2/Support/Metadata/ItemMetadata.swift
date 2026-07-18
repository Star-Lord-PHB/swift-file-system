import Foundation
import PlatformCLib
import SystemPackage
import Testing



/// Independently observed metadata for one filesystem item.
///
/// This type contains only metadata that the test support can observe reliably
/// enough to provide an independent assertion path for `FileInfo` APIs.
extension FileSystemTestSupport {

    struct ItemMetadata: Equatable, Sendable {

        let type: FileAttributeType
        let size: UInt64
        let times: Times


        static func capture(
            at path: FilePath,
            followSymlink: Bool = true
        ) throws -> ItemMetadata {
            let url = followSymlink
                ? URL(filePath: path.string).resolvingSymlinksInPath()
                : URL(filePath: path.string)
            let fileManagerAttributes = try FileManager.default.attributesOfItem(
                atPath: url.path
            )

            let times = try Times.capture(at: path, followSymlink: followSymlink)

            let foundationType = try #require(fileManagerAttributes[.type] as? FileAttributeType)
            let size = try #require(fileManagerAttributes[.size] as? NSNumber)

            return .init(
                type: foundationType,
                size: size.uint64Value,
                times: times
            )
        }

    }

}



extension FileSystemTestSupport.ItemMetadata {

    struct Times: Equatable, Sendable {

        let access: Date?
        let modification: Date?
        let statusChange: Date?
        let creation: Date?


        static func capture(
            at path: FilePath,
            followSymlink: Bool
        ) throws -> Times {
            #if canImport(WinSDK)
            try captureWindowsTimes(at: path, followSymlink: followSymlink)
            #else
            try capturePOSIXTimes(at: path, followSymlink: followSymlink)
            #endif
        }

    }

}



#if !canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Times {

    private static func capturePOSIXTimes(
        at path: FilePath,
        followSymlink: Bool
    ) throws -> Self {
        let metadata = try Stat(path, followTargetSymlink: followSymlink)

        return .init(
            access: date(from: metadata.st_atim),
            modification: date(from: metadata.st_mtim),
            statusChange: date(from: metadata.st_ctim),
            creation: try creationDate(
                at: path,
                followSymlink: followSymlink,
                metadata: metadata
            )
        )
    }


    private static func creationDate(
        at path: FilePath,
        followSymlink: Bool,
        metadata: Stat
    ) throws -> Date? {
        #if canImport(Darwin) || os(FreeBSD)
        date(from: metadata.st_birthtim)
        #elseif canImport(Glibc) || canImport(Musl)
        try linuxCreationDate(at: path, followSymlink: followSymlink)
        #elseif os(OpenBSD)
        nil
        #else
        nil
        #endif
    }


    #if canImport(Glibc) || canImport(Musl)
    private static func linuxCreationDate(
        at path: FilePath,
        followSymlink: Bool
    ) throws -> Date? {
        var metadata = StatCompat()
        let flags = followSymlink ? CInt(0) : CInt(AT_SYMLINK_NOFOLLOW)
        let result = path.withPlatformString { pathPointer in
            systemStatCompat(pathPointer, flags, &metadata)
        }
        try #require(result == 0)
        guard metadata.has_btime != 0 else { return nil }
        return date(from: metadata.st_btim)
    }
    #endif


    private static func date(from value: timespec) -> Date {
        .init(timeIntervalSince1970: TimeInterval(value.tv_sec) + TimeInterval(value.tv_nsec) / 1_000_000_000)
    }

}
#endif



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Times {

    private static func captureWindowsTimes(
        at path: FilePath,
        followSymlink: Bool
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
        try #require(handle != INVALID_HANDLE_VALUE)
        defer { CloseHandle(handle) }

        var metadata = FILE_BASIC_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileBasicInfo,
                &metadata,
                DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        )

        return .init(
            access: date(from: metadata.LastAccessTime),
            modification: date(from: metadata.LastWriteTime),
            statusChange: date(from: metadata.ChangeTime),
            creation: date(from: metadata.CreationTime)
        )
    }


    private static func date(from value: LARGE_INTEGER) -> Date {
        let secondsSince1601 = TimeInterval(value.QuadPart) / 10_000_000
        return .init(timeIntervalSince1970: secondsSince1601 - 11_644_473_600)
    }

}
#endif

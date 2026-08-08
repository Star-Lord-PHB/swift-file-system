import Foundation
import PlatformCLib
import SystemPackage
import Testing

#if canImport(WinSDK)
import WinSDK
#endif

/// Fixture-side file-time manipulation, independent of the library under test.
extension FileSystemTestSupport {

    /// Moves the access time of the item at `path` into the past without
    /// touching its modification time.
    ///
    /// Foundation's `setAttributes` cannot express this: writing any date
    /// attribute rewrites access and modification time together, which leaves
    /// the access time at or behind the modification time and stops
    /// relatime-style volumes from updating it on later reads.
    static func ageAccessTime(
        at path: FilePath,
        by seconds: Int64 = 86_400,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let times = try ItemMetadata.Times.capture(
            at: path,
            sourceLocation: sourceLocation
        )
        try writeAccessTime(
            times.access.adding(seconds: -seconds),
            at: path,
            sourceLocation: sourceLocation
        )
    }


    /// Whether reads on `workspace`'s volume push access times forward.
    ///
    /// Access-time updates are a per-volume policy (relatime, `noatime`, NTFS
    /// `disablelastaccess`), so access-time tests probe first and cancel when
    /// updates are disabled. The probe file is created at a fixed path inside
    /// the workspace; call at most once per workspace.
    static func volumeUpdatesAccessTimeOnRead(
        in workspace: Workspace,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Bool {
        let probe = try workspace.makeFile(
            at: "access-time-read-probe",
            contents: "probe"
        )
        try ageAccessTime(at: probe, sourceLocation: sourceLocation)
        let before = try ItemMetadata.Times.capture(
            at: probe,
            sourceLocation: sourceLocation
        ).access
        try readOneByte(at: probe, sourceLocation: sourceLocation)
        let after = try ItemMetadata.Times.capture(
            at: probe,
            sourceLocation: sourceLocation
        ).access
        return after > before
    }

}



#if !canImport(WinSDK)
extension FileSystemTestSupport {

    #if canImport(Darwin) || os(FreeBSD)
    /// Lowers the birth time of the item at `path` to `target` while keeping
    /// its modification time.
    ///
    /// Uses the same platform semantics the copy implementation relies on:
    /// setting a modification time earlier than the current birth time also
    /// lowers the birth time. `target` must therefore be earlier than the
    /// item's current birth time; a later value is silently ignored by the
    /// platform.
    static func ageCreationTime(
        at path: FilePath,
        to target: ItemMetadata.Timestamp,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let times = try ItemMetadata.Times.capture(
            at: path,
            sourceLocation: sourceLocation
        )
        try writeTimes(
            access: nil,
            modification: target,
            at: path,
            sourceLocation: sourceLocation
        )
        try writeTimes(
            access: nil,
            modification: times.modification,
            at: path,
            sourceLocation: sourceLocation
        )
    }
    #endif


    fileprivate static func writeAccessTime(
        _ access: ItemMetadata.Timestamp,
        at path: FilePath,
        sourceLocation: SourceLocation
    ) throws {
        try writeTimes(
            access: access,
            modification: nil,
            at: path,
            sourceLocation: sourceLocation
        )
    }


    private static func writeTimes(
        access: ItemMetadata.Timestamp?,
        modification: ItemMetadata.Timestamp?,
        at path: FilePath,
        sourceLocation: SourceLocation
    ) throws {
        func platformTime(_ timestamp: ItemMetadata.Timestamp?) -> timespec {
            guard let timestamp else {
                return timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))
            }
            return timespec(
                tv_sec: time_t(timestamp.secondsSinceUnixEpoch),
                tv_nsec: .init(timestamp.nanoseconds)
            )
        }
        let times = (platformTime(access), platformTime(modification))
        let result = path.withPlatformString { pathPointer in
            withUnsafePointer(to: times) { timesPointer in
                timesPointer.withMemoryRebound(to: timespec.self, capacity: 2) {
                    utimensat(AT_FDCWD, pathPointer, $0, AT_SYMLINK_NOFOLLOW)
                }
            }
        }
        try #require(result == 0, sourceLocation: sourceLocation)
    }


    fileprivate static func readOneByte(
        at path: FilePath,
        sourceLocation: SourceLocation
    ) throws {
        let descriptor = path.withPlatformString { open($0, O_RDONLY) }
        try #require(descriptor >= 0, sourceLocation: sourceLocation)
        defer { close(descriptor) }
        var byte = UInt8(0)
        try #require(read(descriptor, &byte, 1) == 1, sourceLocation: sourceLocation)
    }

}
#endif



#if canImport(WinSDK)
extension FileSystemTestSupport {

    fileprivate static func writeAccessTime(
        _ access: ItemMetadata.Timestamp,
        at path: FilePath,
        sourceLocation: SourceLocation
    ) throws {
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(FILE_WRITE_ATTRIBUTES),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT),
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        // `fileTimeSpec` already expresses the value relative to the 1601 epoch.
        let spec = access.fileTimeSpec
        let ticks = Int64(spec.seconds) * 10_000_000 + Int64(spec.nanoseconds) / 100
        var fileTime = FILETIME(
            dwLowDateTime: DWORD(truncatingIfNeeded: ticks),
            dwHighDateTime: DWORD(truncatingIfNeeded: ticks >> 32)
        )
        try #require(
            SetFileTime(handle, nil, &fileTime, nil),
            sourceLocation: sourceLocation
        )
    }


    fileprivate static func readOneByte(
        at path: FilePath,
        sourceLocation: SourceLocation
    ) throws {
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                GENERIC_READ,
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                0,
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }
        var byte = UInt8(0)
        var bytesRead = DWORD(0)
        try #require(
            ReadFile(handle, &byte, 1, &bytesRead, nil) && bytesRead == 1,
            sourceLocation: sourceLocation
        )
    }

}
#endif

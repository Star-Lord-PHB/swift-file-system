import PlatformCLib
import CFileSystem


/// A time instant
public struct FileTimeSpec: Sendable, Equatable, Hashable {

    /// The seconds part of the time instant
    public let seconds: Int
    /// The nanoseconds part of the time instant
    public let nanoseconds: Int

    @inlinable
    public init(seconds: Int, nanoseconds: Int) {
        self.seconds = seconds
        self.nanoseconds = nanoseconds
    }

    #if canImport(WinSDK)
    /// Create a `FileTimeSpec` from platform specific file timespec.
    @inlinable
    public init(platformFileTime: FILETIME) {
        let hundredNanoSeconds = (UInt64(platformFileTime.dwHighDateTime) << 32 | UInt64(platformFileTime.dwLowDateTime))
        let seconds = hundredNanoSeconds / 10_000_000
        let nanoseconds = (hundredNanoSeconds % 10_000_000) * 100
        self.init(seconds: Int(seconds), nanoseconds: Int(nanoseconds))
    }
    /// Create a `FileTimeSpec` from platform specific file timespec.
    @inlinable
    public init(platformFileTime: LARGE_INTEGER) {
        let hundredNanoSeconds = UInt64(platformFileTime.QuadPart)
        let seconds = hundredNanoSeconds / 10_000_000
        let nanoseconds = (hundredNanoSeconds % 10_000_000) * 100
        self.init(seconds: Int(seconds), nanoseconds: Int(nanoseconds))
    }
    #else
    /// Create a `FileTimeSpec` from platform specific file timespec.
    @inlinable
    public init(platformFileTime: timespec) {
        self.init(seconds: platformFileTime.tv_sec, nanoseconds: platformFileTime.tv_nsec)
    }
    #endif

    /// Convert to platform specific file timespec.
    @inlinable
    public var platformFileTime: PlatformInteropTypes.FileTime {
        #if canImport(WinSDK)
        var filetime = FILETIME()
        let hundredNanoSeconds = UInt64(seconds) * 10_000_000 + UInt64(nanoseconds) / 100
        filetime.dwLowDateTime = DWORD(hundredNanoSeconds & 0xFFFFFFFF)
        filetime.dwHighDateTime = DWORD((hundredNanoSeconds >> 32) & 0xFFFFFFFF)
        return filetime
        #else 
        return .init(tv_sec: seconds, tv_nsec: nanoseconds)
        #endif 
    }


    #if !canImport(WinSDK)
    static var utimeOmit: FileTimeSpec {
        .init(platformFileTime: .init(tv_sec: 0, tv_nsec: .init(UTIME_OMIT)))
    }

    static var utimeNow: FileTimeSpec {
        .init(platformFileTime: .init(tv_sec: 0, tv_nsec: .init(UTIME_NOW)))
    }
    #endif

}



extension FileTimeSpec: CustomStringConvertible {

    @inlinable
    public var description: String {
        "FileTimeSpec(seconds: \(seconds), nanoseconds: \(nanoseconds))"
    }

}



#if canImport(WinSDK)
extension FILETIME {
    public init(largeInteger: LARGE_INTEGER) {
        self.init(
            dwLowDateTime: DWORD(largeInteger.LowPart), 
            dwHighDateTime: DWORD(bitPattern: largeInteger.HighPart)
        )
    }
}
#endif



/// A collection of all the time instants of a file
/// 
/// Includes the access time, modification time, change time and creation time. 
/// 
/// The creation time may not be available on all platforms, in which case it will be `nil`.
public struct FileTimes: Sendable, Equatable, Hashable {

    /// The last access time of the file
    public let lastAccess: FileTimeSpec
    /// The last modification time of the file
    public let lastModification: FileTimeSpec
    /// The last status change time of the file
    public let lastChange: FileTimeSpec
    /// The creation time of the file, if available
    public let creation: FileTimeSpec?

    public init(
        lastAccess: FileTimeSpec,
        lastModification: FileTimeSpec,
        lastChange: FileTimeSpec,
        creation: FileTimeSpec?
    ) {
        self.lastAccess = lastAccess
        self.lastModification = lastModification
        self.lastChange = lastChange
        self.creation = creation
    }

    public init(
        lastAccess: PlatformInteropTypes.FileTime,
        lastModification: PlatformInteropTypes.FileTime,
        lastChange: PlatformInteropTypes.FileTime,
        creation: PlatformInteropTypes.FileTime?
    ) {
        self.init(
            lastAccess: .init(platformFileTime: lastAccess), 
            lastModification: .init(platformFileTime: lastModification), 
            lastChange: .init(platformFileTime: lastChange), 
            creation: creation.map { .init(platformFileTime: $0) }
        )
    }

}

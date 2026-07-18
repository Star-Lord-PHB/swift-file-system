import PlatformCLib
import CFileSystem

#if canImport(Glibc) || canImport(Musl)
import struct CSystem.timespec
#endif


public struct FileTimeSpec: Sendable, Equatable, Hashable {

    public let seconds: Int
    public let nanoseconds: Int

    @inlinable
    public init(seconds: Int, nanoseconds: Int) {
        self.seconds = seconds
        self.nanoseconds = nanoseconds
    }

    #if canImport(WinSDK)
    @inlinable
    public init(platformFileTime: FILETIME) {
        let hundredNanoSeconds = (UInt64(platformFileTime.dwHighDateTime) << 32 | UInt64(platformFileTime.dwLowDateTime))
        let seconds = hundredNanoSeconds / 10_000_000
        let nanoseconds = (hundredNanoSeconds % 10_000_000) * 100
        self.init(seconds: Int(seconds), nanoseconds: Int(nanoseconds))
    }
    @inlinable
    public init(platformFileTime: LARGE_INTEGER) {
        let hundredNanoSeconds = UInt64(platformFileTime.QuadPart)
        let seconds = hundredNanoSeconds / 10_000_000
        let nanoseconds = (hundredNanoSeconds % 10_000_000) * 100
        self.init(seconds: Int(seconds), nanoseconds: Int(nanoseconds))
    }
    #else
    @inlinable
    public init(platformFileTime: timespec) {
        self.init(seconds: platformFileTime.tv_sec, nanoseconds: platformFileTime.tv_nsec)
    }
    #endif

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



public struct FileTimes: Sendable, Equatable, Hashable {
    public let lastAccess: FileTimeSpec
    public let lastModification: FileTimeSpec
    public let lastChange: FileTimeSpec
    public let creation: FileTimeSpec?
}



extension FileTimes {

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

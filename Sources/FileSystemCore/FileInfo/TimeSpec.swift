import Foundation 
import PlatformCLib
import SystemPackage
import CFileSystem

#if canImport(Glibc) || canImport(Musl)
import CDispatch
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
    public var date: Date {
        #if canImport(WinSDK)
        .init(timeIntervalSinceReferenceDate: TimeInterval(seconds) - Date.timeIntervalBetween1601AndReferenceDate + TimeInterval(nanoseconds) / 1_000_000_000)
        #else
        .init(timeIntervalSinceReferenceDate: TimeInterval(seconds) - Date.timeIntervalBetween1970AndReferenceDate + TimeInterval(nanoseconds) / 1_000_000_000)
        #endif 
    }

    @inlinable
    public var platformFileTime: CInterop.PlatformFileTime {
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
        date.description
    }

}



extension FileTimeSpec {

    public init(from date: Date) {
        #if canImport(WinSDK)
        let timeInterval = date.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1601AndReferenceDate
        #else
        let timeInterval = date.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
        #endif 
        let seconds = Int(timeInterval)
        let nanoseconds = Int((timeInterval - TimeInterval(seconds)) * 1_000_000_000)
        self.init(seconds: seconds, nanoseconds: nanoseconds)
    }

}



extension Date {
    @usableFromInline static let timeIntervalBetween1601AndReferenceDate: TimeInterval = 12622780800
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
        lastAccess: CInterop.PlatformFileTime,
        lastModification: CInterop.PlatformFileTime,
        lastChange: CInterop.PlatformFileTime,
        creation: CInterop.PlatformFileTime?
    ) {
        self.init(
            lastAccess: .init(platformFileTime: lastAccess), 
            lastModification: .init(platformFileTime: lastModification), 
            lastChange: .init(platformFileTime: lastChange), 
            creation: creation.map { .init(platformFileTime: $0) }
        )
    }

}
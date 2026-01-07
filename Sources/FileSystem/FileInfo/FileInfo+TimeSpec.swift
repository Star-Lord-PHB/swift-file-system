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

}



extension FileTimeSpec: CustomStringConvertible {

    @inlinable
    public var description: String {
        date.description
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
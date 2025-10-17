import Foundation 
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


extension FileInfo {

    public struct PlatformTimeSpec: Sendable, Equatable, Hashable {

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
            let hundredNanoSeconds = (UINT64(platformFileTime.dwHighDateTime) << 32 | UInt64(platformFileTime.dwLowDateTime))
            let seconds = hundredNanoSeconds / 10_000_000
            let nanoseconds = (hundredNanoSeconds % 10_000_000) * 100
            self.init(seconds: Int(seconds), nanoseconds: Int(nanoseconds))
        }
        #else
        @inlinable
        public init(platformFileTime: timespec) {
            self.init(seconds: timespec.tv_sec, nanoseconds: timespec.tv_nsec)
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

    }

}



extension FileInfo.PlatformTimeSpec: CustomStringConvertible {

    @inlinable
    public var description: String {
        date.description
    }

}



extension Date {
    @usableFromInline static let timeIntervalBetween1601AndReferenceDate: TimeInterval = 12622780800
}
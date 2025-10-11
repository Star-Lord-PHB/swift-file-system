import Foundation 
import SystemPackage


extension FileInfo {

    public struct TimeSpec {

        public let seconds: Int
        public let nanoseconds: Int

        public init(seconds: Int, nanoseconds: Int) {
            self.seconds = seconds
            self.nanoseconds = nanoseconds
        }

        #if !os(Windows)
        public init(timespec: timespec) {
            self.init(seconds: timespec.tv_sec, nanoseconds: timespec.tv_nsec)
        }
        #endif

        public var date: Date {
            .init(timeIntervalSinceReferenceDate: TimeInterval(seconds) - Date.timeIntervalBetween1970AndReferenceDate + TimeInterval(nanoseconds) / 1_000_000_000)
        }

    }

}
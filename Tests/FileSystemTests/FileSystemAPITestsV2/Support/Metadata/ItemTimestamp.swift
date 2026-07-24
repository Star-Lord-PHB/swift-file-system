import PlatformCLib
import SwiftFileSystem



extension FileSystemTestSupport.ItemMetadata {

    /// An exact filesystem timestamp expressed relative to the Unix epoch.
    ///
    /// Unlike `Date`, this representation preserves the native nanosecond or
    /// 100-nanosecond precision used by the underlying platform APIs.
    struct Timestamp: Equatable, Sendable {

        #if canImport(WinSDK)
        private static let secondsBetween1601And1970: Int64 = 11_644_473_600
        #endif

        let secondsSinceUnixEpoch: Int64
        let nanoseconds: Int32


        init(
            secondsSinceUnixEpoch: Int64,
            nanoseconds: Int32
        ) {
            precondition((0..<1_000_000_000).contains(nanoseconds))
            self.secondsSinceUnixEpoch = secondsSinceUnixEpoch
            self.nanoseconds = nanoseconds
        }


        init(fileTimeSpec: FileTimeSpec) {
            precondition((0..<1_000_000_000).contains(fileTimeSpec.nanoseconds))

            #if canImport(WinSDK)
            let secondsSinceUnixEpoch =
                Int64(fileTimeSpec.seconds) - Self.secondsBetween1601And1970
            #else
            let secondsSinceUnixEpoch = Int64(fileTimeSpec.seconds)
            #endif

            self.init(
                secondsSinceUnixEpoch: secondsSinceUnixEpoch,
                nanoseconds: Int32(fileTimeSpec.nanoseconds)
            )
        }


        var fileTimeSpec: FileTimeSpec {
            #if canImport(WinSDK)
            let seconds = secondsSinceUnixEpoch + Self.secondsBetween1601And1970
            #else
            let seconds = secondsSinceUnixEpoch
            #endif

            return .init(
                seconds: Int(seconds),
                nanoseconds: Int(nanoseconds)
            )
        }


        func adding(seconds: Int64) -> Self {
            let result = secondsSinceUnixEpoch.addingReportingOverflow(seconds)
            precondition(!result.overflow)
            return .init(
                secondsSinceUnixEpoch: result.partialValue,
                nanoseconds: nanoseconds
            )
        }

    }

}



#if !canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Timestamp {

    init(platformTime: timespec) {
        self.init(
            secondsSinceUnixEpoch: Int64(platformTime.tv_sec),
            nanoseconds: Int32(platformTime.tv_nsec)
        )
    }

}
#endif



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Timestamp {

    init(platformTime: LARGE_INTEGER) {
        let ticksPerSecond = Int64(10_000_000)
        let secondsSince1601 = platformTime.QuadPart / ticksPerSecond
        let remainingTicks = platformTime.QuadPart % ticksPerSecond

        self.init(
            secondsSinceUnixEpoch: secondsSince1601 - Self.secondsBetween1601And1970,
            nanoseconds: Int32(remainingTicks * 100)
        )
    }

}
#endif

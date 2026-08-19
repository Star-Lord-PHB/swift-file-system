#if !canImport(WinSDK)

import SystemPackage
import PlatformCLib



public struct PosixPollEvent: OptionSet, Sendable {
    public let rawValue: Int16
    public init(rawValue: Int16) {
        self.rawValue = rawValue
    }
    public static let pollIn: PosixPollEvent = .init(rawValue: .init(POLLIN))
    public static let pollOut: PosixPollEvent = .init(rawValue: .init(POLLOUT))
    public static let pollErr: PosixPollEvent = .init(rawValue: .init(POLLERR))
    public static let pollHup: PosixPollEvent = .init(rawValue: .init(POLLHUP))
    public static let pollNVal: PosixPollEvent = .init(rawValue: .init(POLLNVAL))
    public static let pollRdNorm: PosixPollEvent = .init(rawValue: .init(POLLRDNORM))
    public static let pollRdBand: PosixPollEvent = .init(rawValue: .init(POLLRDBAND))
    public static let pollWrNorm: PosixPollEvent = .init(rawValue: .init(POLLWRNORM))
    public static let pollWrBand: PosixPollEvent = .init(rawValue: .init(POLLWRBAND))
}



extension UnsafeSystemHandle {

    public func poll(listening: FileOperationOptions.PosixPollEventToMonitor, waitMilliseconds: CInt? = nil) throws(LowLevelError) -> PosixPollEvent? {

        var pollDescriptor = pollfd(
            fd: self.unsafeRawHandle,
            events: listening.rawValue,
            revents: 0
        )

        let timeout = waitMilliseconds.map { CInt($0) } ?? -1

        let result = PlatformCLib.poll(&pollDescriptor, 1, timeout)
        guard result != 0 else {
            // timeout
            return nil
        }
        guard result > 0 else {
            try LowLevelError.assertError()
        }

        return .init(rawValue: pollDescriptor.revents)

    }

}



extension UnsafeSystemHandle {

    package func futimens(_ times: (FileTimeSpec, FileTimeSpec)) throws(LowLevelError) {
        let platformTimes = (times.0.platformFileTime, times.1.platformFileTime)
        try execThrowingCFunction {
            withUnsafePointer(to: platformTimes) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    PlatformCLib.futimens(self.unsafeRawHandle, reboundPtr)
                }
            }
        }
    }


    package func fstat() throws(LowLevelError) -> PlatformInteropTypes.Stat {

        var st = PlatformInteropTypes.Stat.PlatformStat()

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            PlatformCLib.fstat(unsafeRawHandle, &st)
        }
        #else
        try execThrowingCFunction {
            systemFStatCompat(unsafeRawHandle, &st)
        }
        #endif

        return .init(platformStat: st)

    }

}
#endif

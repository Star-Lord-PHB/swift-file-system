#if !canImport(WinSDK)

import SystemPackage
import PlatformCLib



/// Events that can be observed on a file handle through the `poll`` system call.
public struct PosixPollEvent: OptionSet, Sendable {
    public let rawValue: Int16
    public init(rawValue: Int16) {
        self.rawValue = rawValue
    }
    /// The file descriptor is readable (`POLLIN`).
    public static let pollIn: PosixPollEvent = .init(rawValue: .init(POLLIN))
    /// There is some exceptional condition on the file descriptor (`POLLPRI`).
    public static let pollPri: PosixPollEvent = .init(rawValue: .init(POLLPRI))
    /// The file descriptor is writable (`POLLOUT`).
    public static let pollOut: PosixPollEvent = .init(rawValue: .init(POLLOUT))
    /// An error condition has occurred on the file descriptor (`POLLERR`).
    public static let pollErr: PosixPollEvent = .init(rawValue: .init(POLLERR))
    /// The file descriptor is closed (`POLLHUP`).
    public static let pollHup: PosixPollEvent = .init(rawValue: .init(POLLHUP))
    /// The file descriptor is invalid (`POLLNVAL`).
    public static let pollNVal: PosixPollEvent = .init(rawValue: .init(POLLNVAL))
    /// The file descriptor is readable (`POLLRDNORM`).
    public static let pollRdNorm: PosixPollEvent = .init(rawValue: .init(POLLRDNORM))
    /// Priority band data can be read (`POLLRDBAND`).
    public static let pollRdBand: PosixPollEvent = .init(rawValue: .init(POLLRDBAND))
    /// The file descriptor is writable (`POLLWRNORM`).
    public static let pollWrNorm: PosixPollEvent = .init(rawValue: .init(POLLWRNORM))
    /// Priority band data can be written (`POLLWRBAND`).
    public static let pollWrBand: PosixPollEvent = .init(rawValue: .init(POLLWRBAND))
}



extension UnsafeSystemHandle {

    /// Polls the file handle for the specified events, waiting for a specified time.
    /// - Parameters:
    ///   - listening: The events to listen for on the file handle
    ///   - waitMilliseconds: The maximum time to wait for an event, in milliseconds. If `nil`, waits indefinitely.
    /// - Returns: A `PosixPollEvent` representing the events that occurred, or `nil` if the wait timed out.
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
            _statx(unsafeRawHandle, "", AT_EMPTY_PATH, &st)
        }
        #endif

        return .init(platformStat: st)

    }

}
#endif

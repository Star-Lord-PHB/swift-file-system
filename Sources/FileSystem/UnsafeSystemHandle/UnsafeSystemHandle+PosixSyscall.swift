#if !canImport(WinSDK)

import SystemPackage
import PlatformCLib



extension UnsafeSystemHandle {

    public enum PollEventToMonitor: Int16, Sendable {
        case read
        case write
        case readWrite
        public var rawValue: Int16 {
            switch self {
                case .read:         .init(POLLIN)
                case .write:        .init(POLLOUT)
                case .readWrite:    .init(POLLIN | POLLOUT)
            }
        }
        public init?(rawValue: Int16) {
            switch CInt(rawValue) {
                case POLLIN:            self = .read
                case POLLOUT:           self = .write
                case POLLIN | POLLOUT:  self = .readWrite
                default:                return nil
            }
        }
    }


    public struct PollEvent: OptionSet, Sendable {
        public let rawValue: Int16
        public init(rawValue: Int16) {
            self.rawValue = rawValue
        }
        public static let pollIn: PollEvent = .init(rawValue: .init(POLLIN))
        public static let pollOut: PollEvent = .init(rawValue: .init(POLLOUT))
        public static let pollErr: PollEvent = .init(rawValue: .init(POLLERR))
        public static let pollHup: PollEvent = .init(rawValue: .init(POLLHUP))
        public static let pollNVal: PollEvent = .init(rawValue: .init(POLLNVAL))
        public static let pollRdNorm: PollEvent = .init(rawValue: .init(POLLRDNORM))
        public static let pollRdBand: PollEvent = .init(rawValue: .init(POLLRDBAND))
        public static let pollWrNorm: PollEvent = .init(rawValue: .init(POLLWRNORM))
        public static let pollWrBand: PollEvent = .init(rawValue: .init(POLLWRBAND))
    }


    public func poll(listening: PollEventToMonitor, waitMilliseconds: CInt? = nil) throws(SystemError) -> PollEvent? {

        var pollDescriptor = pollfd(
            fd: self.unsafeRawHandle,
            events: listening.rawValue,
            revents: 0
        )

        let timeout = waitMilliseconds.map { CInt($0) } ?? -1

        let result = PlatformCLib.poll(&pollDescriptor, 1, timeout)
        guard result == 0 else { 
            // timeout
            return nil 
        }
        guard result > 0 else {
            try SystemError.assertError()
        }

        return .init(rawValue: pollDescriptor.revents)

    }

}



extension UnsafeSystemHandle {

    func futimens(_ times: (FileTimeSpec, FileTimeSpec)) throws(SystemError) {
        let platformTimes = (times.0.platformFileTime, times.1.platformFileTime)
        try execThrowingCFunction {
            withUnsafePointer(to: platformTimes) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    PlatformCLib.futimens(self.unsafeRawHandle, reboundPtr)
                }
            }
        }
    }


    func fstat() throws(SystemError) -> CInterop.Stat {

        var st = CInterop.Stat.PlatformStat()

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
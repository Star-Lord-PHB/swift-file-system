#if !canImport(WinSDK)

import PlatformCLib


extension FileError.PlatformErrorCode {

    @inlinable public static var operationNotPermitted: Self { .init(rawValue: EPERM)! }
    @inlinable public static var noSuchFileOrDirectory: Self { .init(rawValue: ENOENT)! }
    @inlinable public static var noSuchProcess: Self { .init(rawValue: ESRCH)! }
    @inlinable public static var interruptedSystemCall: Self { .init(rawValue: EINTR)! }
    @inlinable public static var ioError: Self { .init(rawValue: EIO)! }
    @inlinable public static var noSuchDeviceOrAddress: Self { .init(rawValue: ENXIO)! }
    @inlinable public static var argumentListTooLong: Self { .init(rawValue: E2BIG)! }
    @inlinable public static var badFileDescriptor: Self { .init(rawValue: EBADF)! }
    @inlinable public static var resourceTemporarilyUnavailable: Self { .init(rawValue: EAGAIN)! }
    @inlinable public static var permissionDenied: Self { .init(rawValue: EACCES)! }
    @inlinable public static var badAddress: Self { .init(rawValue: EFAULT)! }
    @inlinable public static var blockDeviceRequired: Self { .init(rawValue: ENOTBLK)! }
    @inlinable public static var deviceOrResourceBusy: Self { .init(rawValue: EBUSY)! }
    @inlinable public static var fileExists: Self { .init(rawValue: EEXIST)! }
    @inlinable public static var crossDeviceLink: Self { .init(rawValue: EXDEV)! }
    @inlinable public static var noSuchDevice: Self { .init(rawValue: ENODEV)! }
    @inlinable public static var notADirectory: Self { .init(rawValue: ENOTDIR)! }
    @inlinable public static var isADirectory: Self { .init(rawValue: EISDIR)! }
    @inlinable public static var invalidArgument: Self { .init(rawValue: EINVAL)! }
    @inlinable public static var tooManyOpenFilesInSystem: Self { .init(rawValue: ENFILE)! }
    @inlinable public static var tooManyOpenFiles: Self { .init(rawValue: EMFILE)! }
    @inlinable public static var textFileBusy: Self { .init(rawValue: ETXTBSY)! }
    @inlinable public static var fileTooLarge: Self { .init(rawValue: EFBIG)! }
    @inlinable public static var noSpaceLeftOnDevice: Self { .init(rawValue: ENOSPC)! }
    @inlinable public static var illegalSeek: Self { .init(rawValue: ESRCH)! }
    @inlinable public static var readOnlyFileSystem: Self { .init(rawValue: EROFS)! }
    @inlinable public static var tooManyLinks: Self { .init(rawValue: EMLINK)! }
    @inlinable public static var brokenPipe: Self { .init(rawValue: EPIPE)! }
    @inlinable public static var resourceDeadlockAvoided: Self { .init(rawValue: EDQUOT)! }
    @inlinable public static var fileNameTooLong: Self { .init(rawValue: ENAMETOOLONG)! }
    @inlinable public static var noLocksAvailable: Self { .init(rawValue: ENOLCK)! }
    @inlinable public static var functionNotImplemented: Self { .init(rawValue: ENOSYS)! }
    @inlinable public static var directoryNotEmpty: Self { .init(rawValue: ENOTEMPTY)! }
    @inlinable public static var tooManySymbolicLinks: Self { .init(rawValue: EMLINK)! }
    @inlinable public static var valueTooLarge: Self { .init(rawValue: EOVERFLOW)! }
    @inlinable public static var staleFileHandle: Self { .init(rawValue: ESTALE)! }

    #if canImport(Glibc) || canImport(Musl)
    @inlinable public static var noMediumFound: Self { .init(rawValue: ENOMEDIUM)! }
    @inlinable public static var wrongMediumType: Self { .init(rawValue: EMEDIUMTYPE)! }
    #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    @inlinable public static var fileTypeNotSupported: Self { .init(rawValue: EFTYPE)! }
    #endif

    @inlinable public static var wouldBlock: Self { .resourceTemporarilyUnavailable }

}

#endif
#if !canImport(WinSDK)

import PlatformCLib


extension SystemErrorCode {

    /// `EPERM`
    @inlinable public static var operationNotPermitted: Self { .init(rawValue: EPERM) }
    /// `ENOENT`
    @inlinable public static var noSuchFileOrDirectory: Self { .init(rawValue: ENOENT) }
    /// `ESRCH`
    @inlinable public static var noSuchProcess: Self { .init(rawValue: ESRCH) }
    /// `EINTR`
    @inlinable public static var interruptedSystemCall: Self { .init(rawValue: EINTR) }
    /// `EIO`
    @inlinable public static var ioError: Self { .init(rawValue: EIO) }
    /// `ENXIO`
    @inlinable public static var noSuchDeviceOrAddress: Self { .init(rawValue: ENXIO) }
    /// `E2BIG`
    @inlinable public static var argumentListTooLong: Self { .init(rawValue: E2BIG) }
    /// `EBADF`
    @inlinable public static var badFileDescriptor: Self { .init(rawValue: EBADF) }
    /// `EAGAIN`
    @inlinable public static var resourceTemporarilyUnavailable: Self { .init(rawValue: EAGAIN) }
    /// `EACCES`
    @inlinable public static var permissionDenied: Self { .init(rawValue: EACCES) }
    /// `EFAULT`
    @inlinable public static var badAddress: Self { .init(rawValue: EFAULT) }
    /// `ENOTBLK`
    @inlinable public static var blockDeviceRequired: Self { .init(rawValue: ENOTBLK) }
    /// `EBUSY`
    @inlinable public static var deviceOrResourceBusy: Self { .init(rawValue: EBUSY) }
    /// `EEXIST`
    @inlinable public static var fileExists: Self { .init(rawValue: EEXIST) }
    /// `EXDEV`
    @inlinable public static var crossDeviceLink: Self { .init(rawValue: EXDEV) }
    /// `ENODEV`
    @inlinable public static var noSuchDevice: Self { .init(rawValue: ENODEV) }
    /// `ENOTDIR`
    @inlinable public static var notADirectory: Self { .init(rawValue: ENOTDIR) }
    /// `EISDIR`
    @inlinable public static var isADirectory: Self { .init(rawValue: EISDIR) }
    /// `EINVAL`
    @inlinable public static var invalidArgument: Self { .init(rawValue: EINVAL) }
    /// `ENFILE`
    @inlinable public static var tooManyOpenFilesInSystem: Self { .init(rawValue: ENFILE) }
    /// `EMFILE`
    @inlinable public static var tooManyOpenFiles: Self { .init(rawValue: EMFILE) }
    /// `ETXTBSY`
    @inlinable public static var textFileBusy: Self { .init(rawValue: ETXTBSY) }
    /// `EFBIG`
    @inlinable public static var fileTooLarge: Self { .init(rawValue: EFBIG) }
    /// `ENOSPC`
    @inlinable public static var noSpaceLeftOnDevice: Self { .init(rawValue: ENOSPC) }
    /// `ESPIPE`
    @inlinable public static var illegalSeek: Self { .init(rawValue: ESPIPE) }
    /// `EROFS`
    @inlinable public static var readOnlyFileSystem: Self { .init(rawValue: EROFS) }
    /// `EMLINK`
    @inlinable public static var tooManyLinks: Self { .init(rawValue: EMLINK) }
    /// `EPIPE`
    @inlinable public static var brokenPipe: Self { .init(rawValue: EPIPE) }
    /// `EDEADLK`
    @inlinable public static var resourceDeadlockAvoided: Self { .init(rawValue: EDEADLK) }
    /// `ENAMETOOLONG`
    @inlinable public static var fileNameTooLong: Self { .init(rawValue: ENAMETOOLONG) }
    /// `ENOLCK`
    @inlinable public static var noLocksAvailable: Self { .init(rawValue: ENOLCK) }
    /// `ENOSYS`
    @inlinable public static var functionNotImplemented: Self { .init(rawValue: ENOSYS) }
    /// `ENOTEMPTY`
    @inlinable public static var directoryNotEmpty: Self { .init(rawValue: ENOTEMPTY) }
    /// `ELOOP`
    @inlinable public static var tooManyLevelSymbolicLinks: Self { .init(rawValue: ELOOP) }
    /// `EOVERFLOW`
    @inlinable public static var valueTooLarge: Self { .init(rawValue: EOVERFLOW) }
    /// `ESTALE`
    @inlinable public static var staleFileHandle: Self { .init(rawValue: ESTALE) }
    /// `ENOSPC`
    @inlinable public static var noEnoughSpace: Self { .init(rawValue: ENOSPC) }
    /// `ENOTSUP`
    @inlinable public static var operationNotSupported: Self { .init(rawValue: ENOTSUP) }
    /// `ECANCELED`
    @inlinable public static var operationCanceled: Self { .init(rawValue: ECANCELED) }

    #if os(Linux) || os(Android)
    /// `ENOMEDIUM`
    @inlinable public static var noMediumFound: Self { .init(rawValue: ENOMEDIUM) }
    /// `EMEDIUMTYPE`
    @inlinable public static var wrongMediumType: Self { .init(rawValue: EMEDIUMTYPE) }
    #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    /// `EFTYPE`
    @inlinable public static var fileTypeNotSupported: Self { .init(rawValue: EFTYPE) }
    #endif

    /// `EAGAIN`
    @inlinable public static var wouldBlock: Self { .resourceTemporarilyUnavailable }


    package var defaultMappedErrorKind: PlatformErrorKind {
        switch self {
            case .noSuchFileOrDirectory: .notFound
            case .permissionDenied, .operationNotPermitted: .permissionDenied
            case .fileExists: .alreadyExists
            case .invalidArgument: .invalidInput
            case .isADirectory: .isADirectory
            case .notADirectory: .notADirectory
            case .directoryNotEmpty: .notEmptyDirectory
            case .badFileDescriptor: .invalidHandle
            case .noEnoughSpace: .noEnoughSpace
            case .fileNameTooLong: .nameTooLong
            case .operationNotSupported: .unsupported
            case .valueTooLarge: .arithmeticOverflow
            case .tooManyLevelSymbolicLinks: .pathResolutionFailed
            case .brokenPipe: .brokenPipe
            case .operationCanceled: .cancelled
            default: .unknown
        }
    }

}

#endif

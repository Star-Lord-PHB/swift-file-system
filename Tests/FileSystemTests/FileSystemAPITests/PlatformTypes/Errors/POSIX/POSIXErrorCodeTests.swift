#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.ErrorTests {

    @Suite("POSIX error codes")
    struct POSIXErrorCodeTests {}

}



extension PlatformTypesAPITests.ErrorTests.POSIXErrorCodeTests {

    @Test
    func `Success is the zero code`() {

        #expect(SystemErrorCode.success.rawValue == 0)

    }


    @Test(
        arguments: [
            (.operationNotPermitted, EPERM),
            (.noSuchFileOrDirectory, ENOENT),
            (.noSuchProcess, ESRCH),
            (.interruptedSystemCall, EINTR),
            (.ioError, EIO),
            (.noSuchDeviceOrAddress, ENXIO),
            (.argumentListTooLong, E2BIG),
            (.badFileDescriptor, EBADF),
            (.resourceTemporarilyUnavailable, EAGAIN),
            (.wouldBlock, EAGAIN),
            (.permissionDenied, EACCES),
            (.badAddress, EFAULT),
            (.blockDeviceRequired, ENOTBLK),
            (.deviceOrResourceBusy, EBUSY),
            (.fileExists, EEXIST),
            (.crossDeviceLink, EXDEV),
            (.noSuchDevice, ENODEV),
            (.notADirectory, ENOTDIR),
            (.isADirectory, EISDIR),
            (.invalidArgument, EINVAL),
            (.tooManyOpenFilesInSystem, ENFILE),
            (.tooManyOpenFiles, EMFILE),
            (.textFileBusy, ETXTBSY),
            (.fileTooLarge, EFBIG),
            (.noSpaceLeftOnDevice, ENOSPC),
            (.noEnoughSpace, ENOSPC),
            (.illegalSeek, ESPIPE),
            (.readOnlyFileSystem, EROFS),
            (.tooManyLinks, EMLINK),
            (.brokenPipe, EPIPE),
            (.resourceDeadlockAvoided, EDEADLK),
            (.fileNameTooLong, ENAMETOOLONG),
            (.noLocksAvailable, ENOLCK),
            (.functionNotImplemented, ENOSYS),
            (.directoryNotEmpty, ENOTEMPTY),
            (.tooManyLevelSymbolicLinks, ELOOP),
            (.valueTooLarge, EOVERFLOW),
            (.staleFileHandle, ESTALE),
            (.operationNotSupported, ENOTSUP)
        ] as [(SystemErrorCode, CInt)]
    )
    func `Error codes wrap their native errno value`(
        _ code: SystemErrorCode,
        _ rawValue: CInt
    ) {

        #expect(code.rawValue == rawValue)

    }


    #if canImport(Glibc) || canImport(Musl)
    @Test(
        arguments: [
            (.noMediumFound, ENOMEDIUM),
            (.wrongMediumType, EMEDIUMTYPE)
        ] as [(SystemErrorCode, CInt)]
    )
    func `Linux only error codes wrap their native errno value`(
        _ code: SystemErrorCode,
        _ rawValue: CInt
    ) {

        #expect(code.rawValue == rawValue)

    }
    #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
    @Test
    func `Darwin and BSD only error code wraps its native errno value`() {

        #expect(SystemErrorCode.fileTypeNotSupported.rawValue == EFTYPE)

    }
    #endif


    @Test(
        arguments: [
            (.noSuchFileOrDirectory, .notFound),
            (.permissionDenied, .permissionDenied),
            (.operationNotPermitted, .permissionDenied),
            (.fileExists, .alreadyExists),
            (.invalidArgument, .invalidInput),
            (.isADirectory, .isADirectory),
            (.notADirectory, .notADirectory),
            (.directoryNotEmpty, .notEmptyDirectory),
            (.badFileDescriptor, .invalidHandle),
            (.noEnoughSpace, .noEnoughSpace),
            (.fileNameTooLong, .nameTooLong),
            (.operationNotSupported, .unsupported),
            (.valueTooLarge, .arithmeticOverflow),
            (.tooManyLevelSymbolicLinks, .pathResolutionFailed),
            (.brokenPipe, .brokenPipe)
        ] as [(SystemErrorCode, PlatformErrorKind)]
    )
    func `Error codes map to their default kind`(
        _ code: SystemErrorCode,
        _ kind: PlatformErrorKind
    ) throws {

        let error = try #require(LowLevelError(systemCode: code))

        #expect(error.kind == kind)

    }


    @Test(
        arguments: [
            .interruptedSystemCall, .ioError, .deviceOrResourceBusy, .crossDeviceLink,
            .staleFileHandle
        ] as [SystemErrorCode]
    )
    func `Unmapped error codes fall back to unknown`(_ code: SystemErrorCode) throws {

        let error = try #require(LowLevelError(systemCode: code))

        #expect(error.kind == .unknown)

    }


    @Test
    func `Last error state produces a matching error`() throws {

        errno = EACCES

        let error = try #require(LowLevelError.fromLastError())

        #expect(error.systemCode == .permissionDenied)
        #expect(error.kind == .permissionDenied)

        errno = 0

        #expect(LowLevelError.fromLastError() == nil)

    }


    @Test
    func `check throws only when the last error is set`() {

        errno = 0

        #expect(throws: Never.self) {
            try LowLevelError.check()
        }

        errno = ENOENT

        let error = #expect(throws: LowLevelError.self) {
            try LowLevelError.check()
        }

        #expect(error?.kind == .notFound)

    }

}

#endif

#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.ErrorTests {

    @Suite("Windows error codes")
    struct WindowsErrorCodeTests {}

}



extension PlatformTypesAPITests.ErrorTests.WindowsErrorCodeTests {

    @Test
    func `Success is the native success code`() {

        #expect(SystemErrorCode.success.rawValue == DWORD(ERROR_SUCCESS))

    }


    @Test(
        arguments: [
            (.invalidFunction, DWORD(ERROR_INVALID_FUNCTION)),
            (.fileNotFound, DWORD(ERROR_FILE_NOT_FOUND)),
            (.pathNotFound, DWORD(ERROR_PATH_NOT_FOUND)),
            (.accessDenied, DWORD(ERROR_ACCESS_DENIED)),
            (.invalidDrive, DWORD(ERROR_INVALID_DRIVE)),
            (.badPathName, DWORD(ERROR_BAD_PATHNAME)),
            (.fileNameTooLong, DWORD(ERROR_FILENAME_EXCED_RANGE)),
            (.invalidFileName, DWORD(ERROR_INVALID_NAME)),
            (.invalidDirectoryName, DWORD(ERROR_DIRECTORY)),
            (.sharingViolation, DWORD(ERROR_SHARING_VIOLATION)),
            (.lockViolation, DWORD(ERROR_LOCK_VIOLATION)),
            (.cannotCreateFile, DWORD(ERROR_CANNOT_MAKE)),
            (.writeProtect, DWORD(ERROR_WRITE_PROTECT)),
            (.userMappedFile, DWORD(ERROR_USER_MAPPED_FILE)),
            (.fileExists, DWORD(ERROR_FILE_EXISTS)),
            (.alreadyExists, DWORD(ERROR_ALREADY_EXISTS)),
            (.openFailed, DWORD(ERROR_OPEN_FAILED)),
            (.diskFull, DWORD(ERROR_DISK_FULL)),
            (.writeFault, DWORD(ERROR_WRITE_FAULT)),
            (.readFault, DWORD(ERROR_READ_FAULT)),
            (.invalidHandle, DWORD(ERROR_INVALID_HANDLE)),
            (.fileCorrupt, DWORD(ERROR_FILE_CORRUPT)),
            (.diskCorrupt, DWORD(ERROR_DISK_CORRUPT)),
            (.handleEOF, DWORD(ERROR_HANDLE_EOF)),
            (.brokenPipe, DWORD(ERROR_BROKEN_PIPE)),
            (.directoryNotEmpty, DWORD(ERROR_DIR_NOT_EMPTY)),
            (.negativeSeek, DWORD(ERROR_NEGATIVE_SEEK)),
            (.badArguments, DWORD(ERROR_BAD_ARGUMENTS)),
            (.notSupported, DWORD(ERROR_NOT_SUPPORTED)),
            (.insufficientBuffer, DWORD(ERROR_INSUFFICIENT_BUFFER)),
            (.arithmeticOverflow, DWORD(ERROR_ARITHMETIC_OVERFLOW)),
            (.cannotResolveFilename, DWORD(ERROR_CANT_RESOLVE_FILENAME)),
            (.notAReparsePoint, DWORD(ERROR_NOT_A_REPARSE_POINT)),
            (.pipeBusy, DWORD(ERROR_PIPE_BUSY)),
            (.noData, DWORD(ERROR_NO_DATA)),
            (.pipeNotConnected, DWORD(ERROR_PIPE_NOT_CONNECTED))
        ] as [(SystemErrorCode, DWORD)]
    )
    func `Error codes wrap their native Win32 value`(
        _ code: SystemErrorCode,
        _ rawValue: DWORD
    ) {

        #expect(code.rawValue == rawValue)

    }


    @Test(
        arguments: [
            (.fileNotFound, .notFound),
            (.pathNotFound, .notFound),
            (.accessDenied, .permissionDenied),
            (.alreadyExists, .alreadyExists),
            (.fileExists, .alreadyExists),
            (.badArguments, .invalidInput),
            (.invalidDirectoryName, .notADirectory),
            (.notAReparsePoint, .notASymlink),
            (.directoryNotEmpty, .notEmptyDirectory),
            (.invalidHandle, .invalidHandle),
            (.diskFull, .noEnoughSpace),
            (.fileNameTooLong, .nameTooLong),
            (.notSupported, .unsupported),
            (.arithmeticOverflow, .arithmeticOverflow),
            (.cannotResolveFilename, .pathResolutionFailed),
            (.brokenPipe, .brokenPipe),
            (.noData, .brokenPipe),
            (.pipeNotConnected, .brokenPipe)
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
            .invalidFunction, .sharingViolation, .lockViolation, .writeProtect,
            .handleEOF, .negativeSeek, .pipeBusy
        ] as [SystemErrorCode]
    )
    func `Unmapped error codes fall back to unknown`(_ code: SystemErrorCode) throws {

        let error = try #require(LowLevelError(systemCode: code))

        #expect(error.kind == .unknown)

    }


    @Test
    func `Last error state produces a matching error`() throws {

        SetLastError(DWORD(ERROR_ACCESS_DENIED))

        let error = try #require(LowLevelError.fromLastError())

        #expect(error.systemCode == .accessDenied)
        #expect(error.kind == .permissionDenied)

        SetLastError(DWORD(ERROR_SUCCESS))

        #expect(LowLevelError.fromLastError() == nil)

    }


    @Test
    func `check throws only when the last error is set`() {

        SetLastError(DWORD(ERROR_SUCCESS))

        #expect(throws: Never.self) {
            try LowLevelError.check()
        }

        SetLastError(DWORD(ERROR_FILE_NOT_FOUND))

        let error = #expect(throws: LowLevelError.self) {
            try LowLevelError.check()
        }

        #expect(error?.kind == .notFound)

    }

}

#endif

#if canImport(WinSDK)
import WinSDK


extension FileError.PlatformErrorCode {

    @inlinable public static var invalidFunction: Self { .init(rawValue: .init(ERROR_INVALID_FUNCTION))! }
    @inlinable public static var fileNotFound: Self { .init(rawValue: .init(ERROR_FILE_NOT_FOUND))! }
    @inlinable public static var pathNotFound: Self { .init(rawValue: .init(ERROR_PATH_NOT_FOUND))! }
    @inlinable public static var accessDenied: Self { .init(rawValue: .init(ERROR_ACCESS_DENIED))! }
    @inlinable public static var invalidDrive: Self { .init(rawValue: .init(ERROR_INVALID_DRIVE))! }
    @inlinable public static var badPathName: Self { .init(rawValue: .init(ERROR_BAD_PATHNAME))! }
    @inlinable public static var fileNameTooLong: Self { .init(rawValue: .init(ERROR_FILENAME_EXCED_RANGE))! }
    @inlinable public static var invalidFileName: Self { .init(rawValue: .init(ERROR_INVALID_NAME))! }
    @inlinable public static var invalidDirectoryName: Self { .init(rawValue: .init(ERROR_DIRECTORY))! }
    @inlinable public static var sharingViolation: Self { .init(rawValue: .init(ERROR_SHARING_VIOLATION))! }
    @inlinable public static var lockViolation: Self { .init(rawValue: .init(ERROR_LOCK_VIOLATION))! }
    @inlinable public static var cannotCreateFile: Self { .init(rawValue: .init(ERROR_CANNOT_MAKE))! }
    @inlinable public static var writeProtect: Self { .init(rawValue: .init(ERROR_WRITE_PROTECT))! }
    @inlinable public static var userMappedFile: Self { .init(rawValue: .init(ERROR_USER_MAPPED_FILE))! }
    @inlinable public static var fileExists: Self { .init(rawValue: .init(ERROR_FILE_EXISTS))! }
    @inlinable public static var alreadyExists: Self { .init(rawValue: .init(ERROR_ALREADY_EXISTS))! }
    @inlinable public static var openFailed: Self { .init(rawValue: .init(ERROR_OPEN_FAILED))! }
    @inlinable public static var diskFull: Self { .init(rawValue: .init(ERROR_DISK_FULL))! }
    @inlinable public static var writeFault: Self { .init(rawValue: .init(ERROR_WRITE_FAULT))! }
    @inlinable public static var readFault: Self { .init(rawValue: .init(ERROR_READ_FAULT))! }
    @inlinable public static var invalidHandle: Self { .init(rawValue: .init(ERROR_INVALID_HANDLE))! }
    @inlinable public static var fileCorrupt: Self { .init(rawValue: .init(ERROR_FILE_CORRUPT))! }
    @inlinable public static var diskCorrupt: Self { .init(rawValue: .init(ERROR_DISK_CORRUPT))! }
    @inlinable public static var handleEOF: Self { .init(rawValue: .init(ERROR_HANDLE_EOF))! }
    @inlinable public static var directoryNotEmpty: Self { .init(rawValue: .init(ERROR_DIR_NOT_EMPTY))! }

}

#endif
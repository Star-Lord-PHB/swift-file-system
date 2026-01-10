import Foundation
import SystemPackage



public struct FileError: Error, LocalizedError, CustomStringConvertible {

    public let code: FsErrorCode
    public let operationDescription: OperationDescription

    public var kind: FsErrorCode.Kind { .init(mapping: code) }


    @inlinable
    public init?(code: FsErrorCode, operationDescription: OperationDescription) {
        guard code != .success else { return nil }
        self.code = code
        self.operationDescription = operationDescription
    }


    @inlinable
    public init(systemError: SystemError, operationDescription: OperationDescription) {
        self.init(code: systemError.code, operationDescription: operationDescription)!
    }


    @inlinable
    public var description: String {
        "\(operationDescription): \(code.description)\(code.rawValue.map { " (\($0))" } ?? "")"
    }


    @inlinable
    public var errorDescription: String { description }


    @inlinable
    public static func unknown(operationDescription: OperationDescription) -> FileError {
        .init(code: .extended(.unknown), operationDescription: operationDescription)!
    }

}



extension FileError {

    @inlinable
    public init?(code: CInterop.ErrorCode, operationDescription: OperationDescription) {
        let errorCode = FsErrorCode.PlatformErrorCode(rawValue: code)
        guard errorCode != .success else { return nil }
        self.init(code: .platform(errorCode), operationDescription: operationDescription)
    }


    @inlinable
    public static func fromLastError(operationDescription: @autoclosure () -> OperationDescription) -> FileError? {
        let errorCode = FsErrorCode.PlatformErrorCode.fromLastError()
        guard errorCode != .success else { return nil }
        return .init(code: .platform(errorCode), operationDescription: operationDescription())
    }


    @inlinable
    public static func assertError(fallbackToUnknownError: Bool = false, operationDescription: OperationDescription) throws(FileError) -> Never {
        if let error = FileError(code: .platform(.fromLastError()), operationDescription: operationDescription) {
            throw error
        }
        if fallbackToUnknownError {
            throw .unknown(operationDescription: operationDescription)
        }
        fatalError("Expect to catch an error, but none was thrown")
    }


    @inlinable
    public static func check(operationDescription: @autoclosure () -> OperationDescription) throws(FileError) {
        if let error = fromLastError(operationDescription: operationDescription()) {
            throw error
        }
    }

}



extension FileError {

    public struct OperationDescription: Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {

        public let description: String 

        public init(stringLiteral: String) {
            self.description = stringLiteral
        }

        public init(_ string: String) {
            self.description = string 
        }

        public static func fetchingInfo(for path: FilePath) -> Self {
            "Fetching info for file at \(path)"
        }

        public static func openingHandle(forFileAt path: FilePath) -> Self {
            "Opening file handle for file at \(path)"
        }

        public static func seekingHandle(at path: FilePath, to offset: Int64, relativeTo whence: UnsafeSystemHandle.SeekWhence) -> Self {
            "Seeking handle of file at \(path) to offset \(offset), relative to \(whence)"
        }

        public static func readingHandle(at path: FilePath, offset: Int64? = nil, length: Int64) -> Self {
            if let offset {
                "Reading \(length) bytes from file at \(path) at offset \(offset)"
            } else {
                "Reading \(length) bytes from file at \(path)"
            }
        }

        public static func writingHandle(at path: FilePath, offset: Int64? = nil, length: Int64) -> Self {
            if let offset {
                "Writing \(length) bytes to file at \(path) from offset \(offset)"
            } else {
                "Writing \(length) bytes to file at \(path)"
            }
        }

        public static func openingDirStream(forDirectoryAt path: FilePath) -> Self {
            "Opening directory handle for directory at \(path)"
        }

        public static func readingDirEntries(at path: FilePath) -> Self {
            "Reading directory entries at \(path)"
        }

        public static func resizingHandle(at path: FilePath, toSize size: Int64) -> Self {
            "Resizing file at \(path) to size \(size)"
        }

        public static func synchronizingHandle(at path: FilePath) -> Self {
            "Synchronizing file at \(path)"
        }

        public static func closingHandle(at path: FilePath) -> Self {
            "Closing file at \(path)"
        }

        public static func creatingFile(at path: FilePath, replaceExisting: Bool, permission: FilePermissions? = nil) -> Self {
            "Creating file at \(path) (replaceExisting: \(replaceExisting), permission: \(permission?.description ?? "nil"))"
        }

        public static func createDir(at path: FilePath, withIntermediateDirectories: Bool) -> Self {
            "Creating directory at \(path) \(withIntermediateDirectories ? "with intermediate directories" : "")"
        }

        public static func removingItem(at path: FilePath) -> Self {
            "Removing item at \(path)"
        }

        public static func copyingItem(from srcPath: FilePath, to dstPath: FilePath) -> Self {
            "Copying item from \(srcPath) to \(dstPath)"
        }

        public static func movingItem(from srcPath: FilePath, to dstPath: FilePath) -> Self {
            "Moving item from \(srcPath) to \(dstPath)"
        }

        public static func creatingSymlink(at path: FilePath, pointingTo destPath: FilePath) -> Self {
            "Creating symbolic link at \(path) pointing to \(destPath)"
        }

        public static func creatingHardlink(at path: FilePath, for existingPath: FilePath) -> Self {
            "Creating hard link at \(path) for existing file at \(existingPath)"
        }

        public static func readingSymlink(at path: FilePath) -> Self {
            "Reading symbolic link at \(path)"
        }

        public static func settingFileTimes(at path: FilePath) -> Self {
            "Updating file times at \(path)"
        }

        public static func settingFileAttributes(at path: FilePath) -> Self {
            "Setting file attributes at \(path)"
        }

        public static func gettingFileInodeFlags(at path: FilePath) -> Self {
            "Getting inode flags for file at \(path)"
        }

        public static func settingFileInodeFlags(at path: FilePath) -> Self {
            "Setting inode flags for file at \(path)"
        }

        public static func settingFilePermissions(at path: FilePath) -> Self {
            "Setting file permissions at \(path)"
        }

        public static func settingFileOwner(at path: FilePath) -> Self {
            "Setting file owner at \(path)"
        }

        public static func gettingFileSecurityInfo(at path: FilePath) -> Self {
            "Getting file security info at \(path)"
        }

        public static func settingFileSecurityInfo(at path: FilePath) -> Self {
            "Setting file security info at \(path)"
        }

        public static func queryingAccountName(for identity: PlatformIdentity) -> Self {
            "Querying account name for identity \(identity)"
        }

        public static func queryingIdentity(forAccountName name: String) -> Self {
            "Querying identity for account name \(name)"
        }

        public static func queryingCurrentIdentity() -> Self {
            "Querying current identity"
        }

    }

}
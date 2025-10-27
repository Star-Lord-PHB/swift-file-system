import Foundation
import SystemPackage



public struct FileError: Error, LocalizedError, CustomStringConvertible {

    public let code: PlatformErrorCode?
    public let operationDescription: OperationDescription


    @inlinable
    public init(code: PlatformErrorCode?, operationDescription: OperationDescription) {
        self.code = code
        self.operationDescription = operationDescription
    }


    @inlinable
    public init(systemError: SystemError, operationDescription: OperationDescription) {
        self.init(code: .init(rawValue: systemError.code), operationDescription: operationDescription)
    }


    @inlinable
    public var description: String {
        "\(operationDescription): \(code?.description ?? "Unknown error") (\(code?.rawValue ?? 0))"
    }


    @inlinable
    public var errorDescription: String { description }


    @inlinable
    public static func unknown(operationDescription: OperationDescription) -> FileError {
        .init(code: nil, operationDescription: operationDescription)
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

    }

}
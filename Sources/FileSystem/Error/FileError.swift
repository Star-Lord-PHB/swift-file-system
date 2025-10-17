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

    }

}
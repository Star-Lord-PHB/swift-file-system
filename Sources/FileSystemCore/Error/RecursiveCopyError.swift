import struct SystemPackage.FilePath



public struct RecursiveCopySingleItemError: Sendable, Equatable, Hashable {
    public let itemRelativePath: FilePath
    public let systemCode: SystemErrorCode?
    public let kind: PlatformErrorKind
    public let operation: Operation
    public init(itemRelativePath: FilePath, operation: Operation, code: SystemErrorCode? = nil, kind: PlatformErrorKind? = nil) {
        precondition(code != .success, "code should not be .success for an error")
        precondition(itemRelativePath.isRelative, "itemRelativePath should be relative") 
        self.itemRelativePath = itemRelativePath
        self.systemCode = code
        self.kind = kind ?? code?.defaultMappedErrorKind ?? .unknown
        self.operation = operation
    }
}



extension RecursiveCopySingleItemError {

    public struct Operation: Sendable, Equatable, Hashable {

        private enum Case: Sendable, Equatable, Hashable {
            case getSrcMetadata
            case copyContents
            case copyMetadata
            case copyTimes
            case copyPermissions
            case copyFlags
            case copyExtendedAttributes
            case copyDarwinACL
            case releaseResources
        }

        private let `case`: Case

        private init(_ case: Case) {
            self.case = `case`
        }

        public static var getSrcMetadata: Operation { .init(.getSrcMetadata) }

        public static var copyContents: Operation { .init(.copyContents) }

        public static var copyMetadata: Operation { .init(.copyMetadata) }
        public static var copyTimes: Operation { .init(.copyTimes) }
        public static var copyPermissions: Operation { .init(.copyPermissions) }
        public static var copyFlags: Operation { .init(.copyFlags) }
        public static var copyExtendedAttributes: Operation { .init(.copyExtendedAttributes) }
        public static var copyDarwinACL: Operation { .init(.copyDarwinACL) }

        public static var releaseResources: Operation { .init(.releaseResources) }

    }

}



extension RecursiveCopySingleItemError.Operation: CustomStringConvertible {

    public var description: String {
        switch self.case {
            case .getSrcMetadata:           "getSrcMetadata"
            case .copyContents:             "copyContents"
            case .copyMetadata:             "copyMetadata"
            case .copyTimes:                "copyTimes"
            case .copyPermissions:          "copyPermissions"
            case .copyFlags:                "copyFlags"
            case .copyExtendedAttributes:   "copyExtendedAttributes"
            case .copyDarwinACL:            "copyDarwinACL"
            case .releaseResources:         "releaseResources"
        }
    }

}



public struct RecursiveCopyErrorReport: Sendable, Equatable, Hashable, Error {

    public let srcRootPath: FilePath
    public let dstRootPath: FilePath
    public private(set) var errors: NonEmptyErrorList

    public init(srcRootPath: FilePath, dstRootPath: FilePath, errors: NonEmptyErrorList) {
        self.srcRootPath = srcRootPath
        self.dstRootPath = dstRootPath
        self.errors = errors
    }

    public init(srcRootPath: FilePath, dstRootPath: FilePath, firstError: RecursiveCopySingleItemError) {
        self.srcRootPath = srcRootPath
        self.dstRootPath = dstRootPath
        self.errors = [firstError]
    }

    public mutating func append(_ error: RecursiveCopySingleItemError) {
        errors.append(error)
    }

    public mutating func append<S: Sequence>(contentsOf newErrors: S) where S.Element == RecursiveCopySingleItemError {
        errors.append(contentsOf: newErrors)
    }

    public consuming func throwAsPlatformError() throws(PlatformError) -> Never {
        throw .init(error: self, kind: .unknown, operation: .recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath))
    }

}



extension RecursiveCopyErrorReport {

    public struct NonEmptyErrorList: Sendable, MutableCollection, RandomAccessCollection, Equatable, Hashable, ExpressibleByArrayLiteral {

        private var errors: [RecursiveCopySingleItemError]

        public var startIndex: Int { errors.startIndex }
        public var endIndex: Int { errors.endIndex }

        public var isEmpty: Bool {
            precondition(errors.isEmpty == false, "ErrorList unexpectedly contains no errors")
            return false
        }

        public var first: RecursiveCopySingleItemError {
            get { errors.first! }
            set { errors[errors.startIndex] = newValue }
        }

        public var last: RecursiveCopySingleItemError {
            get { errors.last! }
            set { errors[errors.endIndex - 1] = newValue }
        }

        public subscript(position: Int) -> RecursiveCopySingleItemError {
            get { errors[position] }
            set { errors[position] = newValue }
        }

        public init<S: Sequence>(_ errors: S) where S.Element == RecursiveCopySingleItemError {
            self.errors = Array(errors)
            precondition(self.errors.isEmpty == false, "ErrorList must contain at least one error")
        }

        public init(arrayLiteral elements: RecursiveCopySingleItemError...) {
            self.errors = elements
            precondition(self.errors.isEmpty == false, "ErrorList must contain at least one error")
        }

        public mutating func append(_ error: RecursiveCopySingleItemError) {
            errors.append(error)
        }

        public mutating func append<S: Sequence>(contentsOf newErrors: S) where S.Element == Element {
            errors.append(contentsOf: newErrors)
        }

    }

}



extension RecursiveCopyErrorReport.NonEmptyErrorList: CustomStringConvertible {
    public var description: String { errors.description }
}
import struct SystemPackage.FilePath



/// Type representing the result of a recursive copy operation.
public struct RecursiveCopyResult: Sendable, Equatable, Hashable {

    /// The root path of the source item being copied.
    public let srcRootPath: FilePath
    /// The root path of the destination being copied to.
    public let dstRootPath: FilePath
    /// A list of errors encountered during the recursive copy operation, if any.
    public let itemErrors: NonEmptyItemErrorList?
    /// Whether the recursive copy operation was cancelled.
    public let operationCancelled: Bool

    /// Creates an ``ItemErrorReport`` if there are errors encountered during the operation.
    public func makeItemErrorReport() -> ItemErrorReport? {
        itemErrors.map { .init(srcRootPath: srcRootPath, dstRootPath: dstRootPath, errors: $0) }
    }

    /// Throws a ``PlatformError`` if there are errors encountered during the operation or the operation 
    /// was cancelled.
    public func throwOnErrorOrCancelled() throws(PlatformError) {
        if operationCancelled {
            throw .init(
                error: makeItemErrorReport() ?? CancellationError(), 
                kind: .cancelled, 
                operation: .recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath)
            )
        }
        guard let errorReport = makeItemErrorReport() else { return }
        try errorReport.throwAsPlatformError()
    }

    package init(
        srcRootPath: FilePath,
        dstRootPath: FilePath,
        itemErrors: NonEmptyItemErrorList?,
        operationCancelled: Bool
    ) {
        self.srcRootPath = srcRootPath
        self.dstRootPath = dstRootPath
        self.itemErrors = itemErrors
        self.operationCancelled = operationCancelled
    }

}



extension RecursiveCopyResult {

    /// Type representing a single error encountered during a recursive copy operation on a specific item.
    public struct SingleItemError: Sendable, Equatable, Hashable {
        /// The relative path of the item that encountered the error.
        public let itemRelativePath: FilePath
        /// The system error code associated with the error, if any.
        public let systemCode: SystemErrorCode?
        /// The semantic kind of the error.
        public let kind: PlatformErrorKind
        /// The operation being performed on the item when the error occurred.
        public let operation: ItemOperation
        public init(itemRelativePath: FilePath, operation: ItemOperation, code: SystemErrorCode? = nil, kind: PlatformErrorKind? = nil) {
            precondition(code != .success, "code should not be .success for an error")
            precondition(itemRelativePath.isRelative, "itemRelativePath should be relative") 
            self.itemRelativePath = itemRelativePath
            self.systemCode = code
            self.kind = kind ?? code?.defaultMappedErrorKind ?? .unknown
            self.operation = operation
        }
    }


    /// Type representing an operation being performed on an item during a recursive copy operation.
    public struct ItemOperation: Sendable, Equatable, Hashable {

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

        /// Operation to get the metadata of the source item.
        public static var getSrcMetadata: Self { .init(.getSrcMetadata) }

        /// Operation to copy the contents of the item.
        public static var copyContents: Self { .init(.copyContents) }

        /// Operation to copy the metadata of the item.
        public static var copyMetadata: Self { .init(.copyMetadata) }
        /// Operation to copy the file times of the item.
        public static var copyTimes: Self { .init(.copyTimes) }
        /// Operation to copy the permissions of the item.
        public static var copyPermissions: Self { .init(.copyPermissions) }
        /// Operation to copy the flags (file attributes) of the item.
        public static var copyFlags: Self { .init(.copyFlags) }
        /// Operation to copy the extended attributes of the item.
        public static var copyExtendedAttributes: Self { .init(.copyExtendedAttributes) }
        /// Operation to copy the Darwin ACL of the item (Darwin specific).
        public static var copyDarwinACL: Self { .init(.copyDarwinACL) }

        /// Operation to release any resources associated with the item after the copy operation.
        public static var releaseResources: Self { .init(.releaseResources) }

    }


    /// A report of the list of errors encountered during a recursive copy operation.
    public struct ItemErrorReport: Sendable, Equatable, Hashable, Error {

        /// The root path of the source item being copied.
        public let srcRootPath: FilePath
        /// The root path of the destination being copied to.
        public let dstRootPath: FilePath
        /// The list of errors encountered during the recursive copy operation, guaranteed to be non-empty.
        public let errors: NonEmptyItemErrorList

        public init(srcRootPath: FilePath, dstRootPath: FilePath, errors: NonEmptyItemErrorList) {
            self.srcRootPath = srcRootPath
            self.dstRootPath = dstRootPath
            self.errors = errors
        }

        /// Throws a ``PlatformError`` with this error report.
        /// 
        /// The thrown error will have the report itself as the underlying cause, the kind will be
        /// ``PlatformErrorKind/unknown``, and the operation will be
        /// ``PlatformError/Operation/recursiveCopy(srcRootPath:dstRootPath:)``.
        public consuming func throwAsPlatformError() throws(PlatformError) -> Never {
            throw .init(error: self, kind: .unknown, operation: .recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath))
        }

    }


    /// A non-empty array of errors encountered during a recursive copy operation.
    public struct NonEmptyItemErrorList: Sendable, MutableCollection, RandomAccessCollection, Equatable, Hashable, ExpressibleByArrayLiteral {

        private var errors: [SingleItemError]

        public var startIndex: Int { errors.startIndex }
        public var endIndex: Int { errors.endIndex }

        public var isEmpty: Bool {
            precondition(errors.isEmpty == false, "ErrorList unexpectedly contains no errors")
            return false
        }

        public var first: SingleItemError {
            get { errors.first! }
            set { errors[errors.startIndex] = newValue }
        }

        public var last: SingleItemError {
            get { errors.last! }
            set { errors[errors.endIndex - 1] = newValue }
        }

        public subscript(position: Int) -> SingleItemError {
            get { errors[position] }
            set { errors[position] = newValue }
        }

        public init<S: Sequence>(_ errors: S) where S.Element == SingleItemError {
            self.errors = Array(errors)
            precondition(self.errors.isEmpty == false, "ErrorList must contain at least one error")
        }

        public init(arrayLiteral elements: SingleItemError...) {
            self.errors = elements
            precondition(self.errors.isEmpty == false, "ErrorList must contain at least one error")
        }

        public mutating func append(_ error: SingleItemError) {
            errors.append(error)
        }

        public mutating func append<S: Sequence>(contentsOf newErrors: S) where S.Element == Element {
            errors.append(contentsOf: newErrors)
        }

    }

}



extension RecursiveCopyResult.ItemOperation: CustomStringConvertible {

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


extension RecursiveCopyResult.NonEmptyItemErrorList: CustomStringConvertible {
    public var description: String { errors.description }
}

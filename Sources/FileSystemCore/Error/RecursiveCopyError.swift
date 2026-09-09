import struct SystemPackage.FilePath



public struct RecursiveCopyResult: Sendable, Equatable, Hashable {

    public let srcRootPath: FilePath
    public let dstRootPath: FilePath
    public let itemErrors: NonEmptyItemErrorList?
    public let operationCancelled: Bool

    public func makeItemErrorReport() -> ItemErrorReport? {
        itemErrors.map { .init(srcRootPath: srcRootPath, dstRootPath: dstRootPath, errors: $0) }
    }

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

    public struct SingleItemError: Sendable, Equatable, Hashable {
        public let itemRelativePath: FilePath
        public let systemCode: SystemErrorCode?
        public let kind: PlatformErrorKind
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

        public static var getSrcMetadata: Self { .init(.getSrcMetadata) }

        public static var copyContents: Self { .init(.copyContents) }

        public static var copyMetadata: Self { .init(.copyMetadata) }
        public static var copyTimes: Self { .init(.copyTimes) }
        public static var copyPermissions: Self { .init(.copyPermissions) }
        public static var copyFlags: Self { .init(.copyFlags) }
        public static var copyExtendedAttributes: Self { .init(.copyExtendedAttributes) }
        public static var copyDarwinACL: Self { .init(.copyDarwinACL) }

        public static var releaseResources: Self { .init(.releaseResources) }

    }


    public struct ItemErrorReport: Sendable, Equatable, Hashable, Error {

        public let srcRootPath: FilePath
        public let dstRootPath: FilePath
        public private(set) var errors: NonEmptyItemErrorList

        public init(srcRootPath: FilePath, dstRootPath: FilePath, errors: NonEmptyItemErrorList) {
            self.srcRootPath = srcRootPath
            self.dstRootPath = dstRootPath
            self.errors = errors
        }

        public init(srcRootPath: FilePath, dstRootPath: FilePath, firstError: SingleItemError) {
            self.srcRootPath = srcRootPath
            self.dstRootPath = dstRootPath
            self.errors = [firstError]
        }

        public mutating func append(_ error: SingleItemError) {
            errors.append(error)
        }

        public mutating func append<S: Sequence>(contentsOf newErrors: S) where S.Element == SingleItemError {
            errors.append(contentsOf: newErrors)
        }

        public consuming func throwAsPlatformError() throws(PlatformError) -> Never {
            throw .init(error: self, kind: .unknown, operation: .recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath))
        }

    }


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

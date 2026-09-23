import struct SystemPackage.FilePath



/// Platform-specific error type representing a failure of an operation.
public struct PlatformError: Error, CustomStringConvertible {

    /// Type representing the underlying cause of the error
    public enum Cause: Sendable {
        /// The error is caused by a ``LowLevelError``.
        case lowLevel(LowLevelError)
        /// The error is caused by some other error
        case otherError(error: any Error, kind: PlatformErrorKind)
    }


    /// The underlying cause of the error.
    public let cause: Cause
    /// The operation that failed and caused this error.
    public let operation: Operation

    /// The system error code associated with this error, if any.
    public var systemCode: SystemErrorCode? {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError.systemCode
            case .otherError: nil
        }
    }
    /// The cross-platform semantic kind of this error.
    public var kind: PlatformErrorKind {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError.kind
            case .otherError(_, let kind): kind
        }
    }
    /// The underlying error that caused this error.
    public var underlyingError: any Error {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError
            case .otherError(let error, _): error
        }
    }


    /// Creates a new instance from a cause and an operation.
    /// - Parameters:
    ///   - cause: The underlying cause of the error.
    ///   - operation: The operation that failed and caused this error.
    package init(cause: Cause, operation: Operation) {
        self.cause = cause
        self.operation = operation
    }


    /// Creates a new ``LowLevelError``-caused error from a system error code, a semantic kind, 
    /// and an operation.
    /// - Parameters:
    ///   - systemCode: The system error code associated with this error.
    ///   - kind: The cross-platform semantic kind of this error.
    ///   - operation: The operation that failed and caused this error.
    /// 
    /// If none of the `systemCode` or `kind` are provided, the result will be an ``unknown(operation:)`` error.
    ///
    /// If the `systemCode` is provided while the `kind` is not, the `kind` will be inferred from
    /// the provided `systemCode`.
    /// 
    /// If the `systemCode` is the succes code, the result will be `nil`.
    public init?(systemCode: SystemErrorCode?, kind: PlatformErrorKind? = nil, operation: Operation) {
        guard systemCode != .success else { return nil }
        self.cause = .lowLevel(.init(systemCode: systemCode, kind: kind)!)
        self.operation = operation
    }


    /// Creates a new ``LowLevelError``-caused error from a low-level error, a semantic kind, and an operation.
    /// - Parameters:
    ///   - lowLevelError: The ``LowLevelError`` that caused this error.
    ///   - kind: The cross-platform semantic kind of this error, will override the kind of the lowLevelError.
    ///   - operation: The operation that failed and caused this error.
    public init(lowLevelError: LowLevelError, kind: PlatformErrorKind? = nil, operation: Operation) {
        self.cause = .lowLevel(.init(systemCode: lowLevelError.systemCode, kind: kind ?? lowLevelError.kind)!)
        self.operation = operation
    }


    /// Creates a new instance from an arbitrary error, a semantic kind, and an operation.
    /// - Parameters:
    ///   - error: The underlying error that caused this error.
    ///   - kind: The cross-platform semantic kind of this error.
    ///   - operation: The operation that failed and caused this error.
    /// 
    /// - Note: With this initializer, even if the provided causing error is a ``LowLevelError``, the
    ///         resulting instance will have a cause of ``Cause/otherError(error:kind:)``.
    public init(error: any Error, kind: PlatformErrorKind, operation: Operation) {
        self.cause = .otherError(error: error, kind: kind)
        self.operation = operation
    }


    public var description: String {
        var description = "PlatformError(\(kind), operation: \(operation)"
        switch cause {
            case .lowLevel(let lowLevelError) where lowLevelError.systemCode != nil:
                description += ", systemCode: \(lowLevelError.systemCode!.rawValue)"
            case .otherError(let error, _):
                description += ", underlyingError: \(error)"
            default: break
        }
        description += ")"
        return description
    }


    package func overridingKind(_ kind: PlatformErrorKind) -> Self {
        return switch cause {
            case .lowLevel(let lowLevelError):
                .init(lowLevelError: lowLevelError, kind: kind, operation: operation)
            case .otherError(let error, _):
                .init(error: error, kind: kind, operation: operation)
        }
    }

}



extension PlatformError {

    /// Create an instance representing an unknown error.
    /// - Parameter operation: The operation that failed and caused this error.
    public static func unknown(operation: Operation) -> Self {
        .init(lowLevelError: .unknown, operation: operation)
    }


    /// Create an instance representing a cancellation error.
    /// - Parameter operation: The operation that failed and caused this error.
    /// 
    /// The underlying cause of this error will be a `CancellationError`.
    public static func taskCancelled(operation: Operation) -> Self {
        .init(error: CancellationError(), kind: .cancelled, operation: operation)
    }


    /// Creates a new ``LowLevelError``-caused error from a native error code, a semantic kind, and 
    /// an operation.
    /// - Parameters:
    ///   - rawSystemCode: The native error code.
    ///   - kind: The semantic kind of the error.
    ///   - operation: The operation that failed and caused this error.
    /// 
    /// If none of the `rawSystemCode` or `kind` are provided, the result will be an ``unknown(operation:)`` error.
    ///
    /// If the `rawSystemCode` is provided while the `kind` is not, the `kind` will be inferred from
    /// the provided `rawSystemCode`.
    /// 
    /// If the `rawSystemCode` is the succes code, the result will be `nil`.
    public init?(rawSystemCode: PlatformInteropTypes.ErrorCode?, kind: PlatformErrorKind? = nil, operation: Operation) {
        self.init(systemCode: rawSystemCode.map { .init(rawValue: $0) }, kind: kind, operation: operation)
    }

    
    /// Creates a ``PlatformError`` from the last reported error code of the current thread, or `nil` 
    /// if no error was reported.
    /// - Parameter operation: The operation that failed and caused this error.
    public static func fromLastError(operation: @autoclosure () -> Operation) -> Self? {
        .init(systemCode: .fromLastError(), kind: nil, operation: operation())
    }

    
    /// Asserts that there was an error reported in the current thread and throws a ``PlatformError``
    /// - Parameters: 
    ///   - fallbackToUnknownError: If `true`, throw an ``unknown(operation:)`` error if no error was reported.
    ///                             If `false`, crash the process if no error was reported.
    ///   - operation: The operation that failed and caused this error.
    public static func assertError(fallbackToUnknownError: Bool = false, operation: @autoclosure () -> Operation) throws(Self) -> Never {
        if let error = fromLastError(operation: operation()) {
            throw error
        }
        if fallbackToUnknownError {
            throw .unknown(operation: operation())
        }
        fatalError("Expect to catch an error, but none was thrown")
    }


    /// Checks the last reported error code of the current thread, and throws a ``PlatformError`` if 
    /// an error was reported.
    /// - Parameter operation: The operation that failed and caused this error.
    public static func check(operation: @autoclosure () -> Operation) throws(Self) {
        if let error = fromLastError(operation: operation()) {
            throw error
        }
    }

}



extension PlatformError {

    /// Type representing the operation that failed and caused an error.
    public struct Operation: Sendable, Equatable, Hashable, CustomStringConvertible {

        private let operationCase: OperationCase

        private init(_ operationCase: OperationCase) {
            self.operationCase = operationCase
        }

        public var description: String {
            operationCase.description
        }

    }


    /// Type representing a custom name of the operation that failed and caused an error.
    public struct CustomOperationName: Sendable, Equatable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral {
        /// The unique identifier of the custom operation name.
        public let id: StaticString
        private let _description: (@Sendable () -> String)?
        /// Creates a new custom operation name with a unique identifier and an optional description.
        public init(name: StaticString, description: (@Sendable () -> String)? = nil) {
            self.id = name
            self._description = description
        }
        public init(stringLiteral value: StaticString) {
            self.id = value
            self._description = nil
        }
        public var description: String {
            _description?() ?? String(describing: id)
        }
        public static func == (lhs: CustomOperationName, rhs: CustomOperationName) -> Bool {
            guard lhs.id.utf8CodeUnitCount == rhs.id.utf8CodeUnitCount else {
                return false
            }
            return lhs.id.withUTF8Buffer { lhsBuffer in
                rhs.id.withUTF8Buffer { rhsBuffer in
                    lhsBuffer.elementsEqual(rhsBuffer)
                }
            }
        }
        public func hash(into hasher: inout Hasher) {
            id.withUTF8Buffer { buffer in 
                hasher.combine(bytes: .init(buffer))
            }
        }
    }

}



extension PlatformError.Operation {

    fileprivate enum OperationCase: Sendable, Equatable, Hashable, CustomStringConvertible {

        // Path based FS operations
        case open(_ path: FilePath)
        case createFile(_ path: FilePath)
        case createDirectory(_ path: FilePath)
        case createSymlink(linkPath: FilePath, dstPath: FilePath)
        case createHardLink(linkPath: FilePath, existingPath: FilePath)
        case remove(_ path: FilePath)
        case move(srcPath: FilePath, dstPath: FilePath)
        case copy(srcPath: FilePath, dstPath: FilePath)
        case recursiveCopy(srcRootPath: FilePath, dstRootPath: FilePath)
        case readSymlink(_ path: FilePath)
        case recursiveResolveSymlink(_ path: FilePath)
        case readDirectory(_ path: FilePath)
        case fetchMeta(_ path: FilePath)
        case setMeta(_ path: FilePath)

        // Handle based FS operations
        case readHandle(originalPath: FilePath)
        case writeHandle(originalPath: FilePath)
        case closeHandle(originalPath: FilePath)
        case seekHandle(originalPath: FilePath)
        case readHandleOffset(originalPath: FilePath)
        case resizeHandle(originalPath: FilePath)
        case syncHandle(originalPath: FilePath)

        // Common path query operations
        case queryCurrentWorkingDir
        case queryExecutablePath
        case queryHomeDir
        case queryCacheDir
        case queryTempDir

        // FS irrelevant operations
        case queryAccountNameFromIdentity
        case queryIdentityfromName
        case queryCurrentIdentity 
        case queryEffectiveAccessMask

        case custom(name: PlatformError.CustomOperationName)

        fileprivate var description: String {
            switch self {
                case .open(let path): "open(\(path))"
                case .createFile(let path): "createFile(\(path))"
                case .createDirectory(let path): "createDirectory(\(path))"
                case .createSymlink(let linkPath, let dstPath): "createSymlink(\(linkPath) -> \(dstPath))"
                case .createHardLink(let linkPath, let existingPath): "createHardLink(\(linkPath), existingPath: \(existingPath))"
                case .remove(let path): "remove(\(path))"
                case .move(let srcPath, let dstPath): "move(\(srcPath) -> \(dstPath))"
                case .copy(let srcPath, let dstPath): "copy(\(srcPath) -> \(dstPath))"
                case .recursiveCopy(let srcRootPath, let dstRootPath): "recursiveCopy(\(srcRootPath) -> \(dstRootPath))"
                case .readSymlink(let path): "readSymlink(\(path))"
                case .recursiveResolveSymlink(let path): "recursiveResolveSymlink(\(path))"
                case .readDirectory(let path): "readDirectory(\(path))"
                case .fetchMeta(let path): "fetchMeta(\(path))"
                case .setMeta(let path): "setMeta(\(path))"

                case .readHandle(let originalPath): "readHandle(originalPath: \(originalPath))"
                case .writeHandle(let originalPath): "writeHandle(originalPath: \(originalPath))"
                case .closeHandle(let originalPath): "closeHandle(originalPath: \(originalPath))"
                case .seekHandle(let originalPath): "seekHandle(originalPath: \(originalPath))"
                case .readHandleOffset(let originalPath): "readHandleOffset(originalPath: \(originalPath))"
                case .resizeHandle(let originalPath): "resizeHandle(originalPath: \(originalPath))"
                case .syncHandle(let originalPath): "syncHandle(originalPath: \(originalPath))"

                case .queryCurrentWorkingDir: "queryCurrentWorkingDirectory"
                case .queryExecutablePath: "queryExecutablePath"
                case .queryHomeDir: "queryHomeDirectory"
                case .queryCacheDir: "queryCacheDirectory"
                case .queryTempDir: "queryTemporaryDirectory"

                case .queryAccountNameFromIdentity: "queryAccountName"
                case .queryIdentityfromName: "queryIdentity"
                case .queryCurrentIdentity: "queryCurrentIdentity"
                case .queryEffectiveAccessMask: "queryEffectiveAccessMask"
                
                case .custom(let name): "custom(\(name.id))"
            }
        }

    }

}


 
extension PlatformError.Operation {

    /// Operation of opening a file
    public static func open(_ path: FilePath) -> Self { .init(.open(path)) }
    /// Operation of creating a file
    public static func createFile(_ path: FilePath) -> Self { .init(.createFile(path)) }
    /// Operation of creating a directory
    public static func createDirectory(_ path: FilePath) -> Self { .init(.createDirectory(path)) }
    /// Operation of creating a symbolic link
    public static func createSymlink(linkPath: FilePath, dstPath: FilePath) -> Self { .init(.createSymlink(linkPath: linkPath, dstPath: dstPath)) }
    /// Operation of creating a hard link
    public static func createHardLink(linkPath: FilePath, existingPath: FilePath) -> Self { .init(.createHardLink(linkPath: linkPath, existingPath: existingPath)) }
    /// Operation of removing an item
    public static func remove(_ path: FilePath) -> Self { .init(.remove(path)) }
    /// Operation of moving an item
    public static func move(srcPath: FilePath, dstPath: FilePath) -> Self { .init(.move(srcPath: srcPath, dstPath: dstPath)) }
    /// Operation of copying an item
    public static func copy(srcPath: FilePath, dstPath: FilePath) -> Self { .init(.copy(srcPath: srcPath, dstPath: dstPath)) }
    /// Operation of recursively copying a directory
    public static func recursiveCopy(srcRootPath: FilePath, dstRootPath: FilePath) -> Self { .init(.recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath)) } 
    /// Operation of reading the direct target of a symbolic link
    public static func readSymlink(_ path: FilePath) -> Self { .init(.readSymlink(path)) }
    /// Operation of resolving the final target of a symbolic link recursively
    public static func recursiveResolveSymlink(_ path: FilePath) -> Self { .init(.recursiveResolveSymlink(path)) }
    /// Operation of reading the contents of a directory
    public static func readDirectory(_ path: FilePath) -> Self { .init(.readDirectory(path)) }
    /// Operation of getting the metadata of a file
    public static func fetchMeta(_ path: FilePath) -> Self { .init(.fetchMeta(path)) }
    /// Operation of setting the metadata of a file
    public static func setMeta(_ path: FilePath) -> Self { .init(.setMeta(path)) }

    /// Operation of reading from a file handle
    public static func readHandle(originalPath: FilePath) -> Self { .init(.readHandle(originalPath: originalPath)) }
    /// Operation of writing to a file handle
    public static func writeHandle(originalPath: FilePath) -> Self { .init(.writeHandle(originalPath: originalPath)) }
    /// Operation of closing a file handle
    public static func closeHandle(originalPath: FilePath) -> Self { .init(.closeHandle(originalPath: originalPath)) }
    /// Operation of seeking the pointer of a file handle
    public static func seekHandle(originalPath: FilePath) -> Self { .init(.seekHandle(originalPath: originalPath)) }
    /// Operation of reading the current offset of the pointer of a file handle
    public static func readHandleOffset(originalPath: FilePath) -> Self { .init(.readHandleOffset(originalPath: originalPath)) }
    /// Operation of resizing a file through a file handle
    public static func resizeHandle(originalPath: FilePath) -> Self { .init(.resizeHandle(originalPath: originalPath)) }
    /// Operation of synchronizing a file with the device through a file handle
    public static func syncHandle(originalPath: FilePath) -> Self { .init(.syncHandle(originalPath: originalPath)) }

    /// Operation of getting the current working directory
    public static var queryCurrentWorkingDir: Self { .init(.queryCurrentWorkingDir) }
    /// Operation of getting the executable path
    public static var queryExecutablePath: Self { .init(.queryExecutablePath) }
    /// Operation of getting the home directory
    public static var queryHomeDir: Self { .init(.queryHomeDir) }
    /// Operation of getting the cache directory
    public static var queryCacheDir: Self { .init(.queryCacheDir) }
    /// Operation of getting the temporary directory
    public static var queryTempDir: Self { .init(.queryTempDir) }
    
    /// Operation of getting the account name from an identity
    public static var queryAccountNameFromIdentity: Self { .init(.queryAccountNameFromIdentity) }
    /// Operation of getting the identity from an account name
    public static var queryIdentityfromName: Self { .init(.queryIdentityfromName) }
    /// Operation of getting the current identity
    public static var queryCurrentIdentity: Self { .init(.queryCurrentIdentity) }
    /// Operation of getting the effective access mask for the current process
    public static var queryEffectiveAccessMask: Self { .init(.queryEffectiveAccessMask) }

    /// Custom operation
    public static func custom(name: PlatformError.CustomOperationName) -> Self { .init(.custom(name: name)) }

}

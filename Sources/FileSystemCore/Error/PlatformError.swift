import struct SystemPackage.FilePath



public struct PlatformError: Error, CustomStringConvertible {

    public enum Cause: Sendable {
        case lowLevel(LowLevelError)
        case otherError(error: any Error, kind: PlatformErrorKind)
    }


    public let cause: Cause
    public let operation: Operation

    public var systemCode: SystemErrorCode? {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError.systemCode
            case .otherError: nil
        }
    }
    public var kind: PlatformErrorKind {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError.kind
            case .otherError(_, let kind): kind
        }
    }
    public var underlyingError: any Error {
        switch cause {
            case .lowLevel(let lowLevelError): lowLevelError
            case .otherError(let error, _): error
        }
    }


    package init(cause: Cause, operation: Operation) {
        self.cause = cause
        self.operation = operation
    }


    public init?(systemCode: SystemErrorCode?, kind: PlatformErrorKind? = nil, operation: Operation) {
        guard systemCode != .success else { return nil }
        self.cause = .lowLevel(.init(systemCode: systemCode, kind: kind)!)
        self.operation = operation
    }


    public init(lowLevelError: LowLevelError, kind: PlatformErrorKind? = nil, operation: Operation) {
        self.cause = .lowLevel(.init(systemCode: lowLevelError.systemCode, kind: kind ?? lowLevelError.kind)!)
        self.operation = operation
    }


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

    public static func unknown(operation: Operation) -> Self {
        .init(lowLevelError: .unknown, operation: operation)
    }


    public static func taskCancelled(operation: Operation) -> Self {
        .init(error: CancellationError(), kind: .cancelled, operation: operation)
    }


    public init?(rawSystemCode: PlatformInteropTypes.ErrorCode?, kind: PlatformErrorKind? = nil, operation: Operation) {
        self.init(systemCode: rawSystemCode.map { .init(rawValue: $0) }, kind: kind, operation: operation)
    }

    
    public static func fromLastError(operation: @autoclosure () -> Operation) -> Self? {
        .init(systemCode: .fromLastError(), kind: nil, operation: operation())
    }

    
    public static func assertError(fallbackToUnknownError: Bool = false, operation: @autoclosure () -> Operation) throws(Self) -> Never {
        if let error = fromLastError(operation: operation()) {
            throw error
        }
        if fallbackToUnknownError {
            throw .unknown(operation: operation())
        }
        fatalError("Expect to catch an error, but none was thrown")
    }


    public static func check(operation: @autoclosure () -> Operation) throws(Self) {
        if let error = fromLastError(operation: operation()) {
            throw error
        }
    }

}



extension PlatformError {

    public struct Operation: Sendable, Equatable, Hashable, CustomStringConvertible {

        private let operationCase: OperationCase

        private init(_ operationCase: OperationCase) {
            self.operationCase = operationCase
        }

        public var description: String {
            operationCase.description
        }

    }


    public struct CustomOperationName: Sendable, Equatable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral {
        public let id: StaticString
        private let _description: (@Sendable () -> String)?
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

    public enum OperationCase: Sendable, Equatable, Hashable, CustomStringConvertible {

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

        public var description: String {
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

    public static func open(_ path: FilePath) -> Self { .init(.open(path)) }
    public static func createFile(_ path: FilePath) -> Self { .init(.createFile(path)) }
    public static func createDirectory(_ path: FilePath) -> Self { .init(.createDirectory(path)) }
    public static func createSymlink(linkPath: FilePath, dstPath: FilePath) -> Self { .init(.createSymlink(linkPath: linkPath, dstPath: dstPath)) }
    public static func createHardLink(linkPath: FilePath, existingPath: FilePath) -> Self { .init(.createHardLink(linkPath: linkPath, existingPath: existingPath)) }
    public static func remove(_ path: FilePath) -> Self { .init(.remove(path)) }
    public static func move(srcPath: FilePath, dstPath: FilePath) -> Self { .init(.move(srcPath: srcPath, dstPath: dstPath)) }
    public static func copy(srcPath: FilePath, dstPath: FilePath) -> Self { .init(.copy(srcPath: srcPath, dstPath: dstPath)) }
    public static func recursiveCopy(srcRootPath: FilePath, dstRootPath: FilePath) -> Self { .init(.recursiveCopy(srcRootPath: srcRootPath, dstRootPath: dstRootPath)) } 
    public static func readSymlink(_ path: FilePath) -> Self { .init(.readSymlink(path)) }
    public static func recursiveResolveSymlink(_ path: FilePath) -> Self { .init(.recursiveResolveSymlink(path)) }
    public static func readDirectory(_ path: FilePath) -> Self { .init(.readDirectory(path)) }
    public static func fetchMeta(_ path: FilePath) -> Self { .init(.fetchMeta(path)) }
    public static func setMeta(_ path: FilePath) -> Self { .init(.setMeta(path)) }

    public static func readHandle(originalPath: FilePath) -> Self { .init(.readHandle(originalPath: originalPath)) }
    public static func writeHandle(originalPath: FilePath) -> Self { .init(.writeHandle(originalPath: originalPath)) }
    public static func closeHandle(originalPath: FilePath) -> Self { .init(.closeHandle(originalPath: originalPath)) }
    public static func seekHandle(originalPath: FilePath) -> Self { .init(.seekHandle(originalPath: originalPath)) }
    public static func readHandleOffset(originalPath: FilePath) -> Self { .init(.readHandleOffset(originalPath: originalPath)) }
    public static func resizeHandle(originalPath: FilePath) -> Self { .init(.resizeHandle(originalPath: originalPath)) }
    public static func syncHandle(originalPath: FilePath) -> Self { .init(.syncHandle(originalPath: originalPath)) }

    public static var queryCurrentWorkingDir: Self { .init(.queryCurrentWorkingDir) }
    public static var queryExecutablePath: Self { .init(.queryExecutablePath) }
    public static var queryHomeDir: Self { .init(.queryHomeDir) }
    public static var queryCacheDir: Self { .init(.queryCacheDir) }
    public static var queryTempDir: Self { .init(.queryTempDir) }
    public static var queryAccountNameFromIdentity: Self { .init(.queryAccountNameFromIdentity) }
    public static var queryIdentityfromName: Self { .init(.queryIdentityfromName) }
    public static var queryCurrentIdentity: Self { .init(.queryCurrentIdentity) }
    public static var queryEffectiveAccessMask: Self { .init(.queryEffectiveAccessMask) }

    public static func custom(name: PlatformError.CustomOperationName) -> Self { .init(.custom(name: name)) }

}
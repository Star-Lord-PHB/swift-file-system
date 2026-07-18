import SystemPackage



public struct PlatformError: Error, CustomStringConvertible {

    public let code: PlatformErrorCode
    public let operation: Operation
    public let underlyingError: (any Error)?

    public var kind: PlatformErrorCode.Kind { code.mappedErrorKind }


    public init?(code: PlatformErrorCode, operation: Operation, underlyingError: (any Error)? = nil) {
        guard code != .success else { return nil }
        self.code = code
        self.operation = operation
        self.underlyingError = underlyingError
    }


    public init(systemError: SystemError, operation: Operation, underlyingError: (any Error)? = nil) {
        self.init(code: systemError.code, operation: operation, underlyingError: underlyingError)!
    }


    public var description: String {
        """
        PlatformError(\
        operation: \(operation)\
        \(code.rawValue.map { ", code: \($0)" } ?? "")\
        \(underlyingError.map { ", underlyingError: \($0)" } ?? "")\
        )
        """
    }

}



extension PlatformError {

    public static func unknown(operation: Operation, underlyingError: (any Error)? = nil) -> Self {
        .init(code: .extended(.unknown), operation: operation, underlyingError: underlyingError)!
    }


    public init?(code: PlatformInteropTypes.ErrorCode, operation: Operation, underlyingError: (any Error)? = nil) {
        self.init(code: .system(.init(rawValue: code)), operation: operation, underlyingError: underlyingError)
    }

    
    public static func fromLastError(operation: @autoclosure () -> Operation) -> Self? {
        .init(code: .system(.fromLastError()), operation: operation(), underlyingError: nil)
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

    public enum Operation: Sendable, Equatable, Hashable, CustomStringConvertible {

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

        case custom(name: CustomOperationName)

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

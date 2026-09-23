

/// Cross-platform semantic kind of an error.
public struct PlatformErrorKind: Sendable, Equatable, Hashable {

    private enum KindCases: Sendable, Equatable, Hashable {

        case notFound
        case permissionDenied
        case alreadyExists
        case invalidInput
        case isADirectory
        case notADirectory
        case notASymlink
        case notEmptyDirectory
        case invalidHandle
        case noEnoughSpace
        case nameTooLong
        case unsupported
        case arithmeticOverflow
        case pathResolutionFailed
        case peerUnavailable
        case brokenPipe
        case cancelled

        case windowsPermissionDeniedOrIsADirectory

        case unknown

    }

    private let kindCases: KindCases

    private init(_ kindCases: KindCases) {
        self.kindCases = kindCases
    }

    /// Checks if the current kind is the same or a more general kind than the provided kind.
    public func maybe(_ kind: PlatformErrorKind) -> Bool {
        if self == kind { return true }
        return switch self.kindCases {
            case .windowsPermissionDeniedOrIsADirectory:
                kind.kindCases == .permissionDenied || kind.kindCases == .isADirectory
            default: false
        }
    }

    /// Item not found.
    public static var notFound: PlatformErrorKind { .init(.notFound) }
    /// Permission denied.
    public static var permissionDenied: PlatformErrorKind { .init(.permissionDenied) }
    /// Item already exists.
    public static var alreadyExists: PlatformErrorKind { .init(.alreadyExists) } 
    /// Invalid input / argument.
    public static var invalidInput: PlatformErrorKind { .init(.invalidInput) }
    /// Item is unexpectedly a directory.
    public static var isADirectory: PlatformErrorKind { .init(.isADirectory) }       
    /// Item is not a directory.
    public static var notADirectory: PlatformErrorKind { .init(.notADirectory) }
    /// Item is not a symlink.
    public static var notASymlink: PlatformErrorKind { .init(.notASymlink) }
    /// Item is a directory with contents.
    public static var notEmptyDirectory: PlatformErrorKind { .init(.notEmptyDirectory) }
    /// The handle is invalid.
    public static var invalidHandle: PlatformErrorKind { .init(.invalidHandle) }
    /// Not enough space to perform the operation.
    public static var noEnoughSpace: PlatformErrorKind { .init(.noEnoughSpace) }
    /// Name of the item is too long.
    public static var nameTooLong: PlatformErrorKind { .init(.nameTooLong) }
    /// The operation is not supported on the current platform or the current item.
    public static var unsupported: PlatformErrorKind { .init(.unsupported) }
    /// Unknown error.
    public static var unknown: PlatformErrorKind { .init(.unknown) }
    /// The operation caused an arithmetic overflow.
    public static var arithmeticOverflow: PlatformErrorKind { .init(.arithmeticOverflow) }
    /// The operation failed to resolve the path.
    public static var pathResolutionFailed: PlatformErrorKind { .init(.pathResolutionFailed) }
    /// The peer is unavailable.
    public static var peerUnavailable: PlatformErrorKind { .init(.peerUnavailable) }
    /// The pipe is broken.
    public static var brokenPipe: PlatformErrorKind { .init(.brokenPipe) }
    /// The operation was cancelled. 
    /// 
    /// Without a `systemCode`, the cancellation was library-generated, otherwise, the OS reported the 
    /// cancellation (e.g. POSIX `ECANCELED`, Windows `ERROR_OPERATION_ABORTED` or `ERROR_REQUEST_ABORTED`).
    public static var cancelled: PlatformErrorKind { .init(.cancelled) }


    public enum Windows {
        /// Permission denied or the item is unexpectedly a directory.
        /// 
        /// On Windows, both error semantics are reported as the same error code `ERROR_ACCESS_DENIED`, making
        /// it impossible to distinguish between them. This kind is a general one representing both cases.
        public static var permissionDeniedOrIsADirectory: PlatformErrorKind { .init(.windowsPermissionDeniedOrIsADirectory) }
    }

    public enum Posix {
        // not needed yet
    }


    /// Namespace for POSIX-specific error kinds.
    public static var posix: Posix.Type { Posix.self }
    /// Namespace for Windows-specific error kinds.
    public static var windows: Windows.Type { Windows.self }

}



extension PlatformErrorKind: CustomStringConvertible {

    public var description: String {
        return switch kindCases {
            case .notFound: "Item not found"
            case .permissionDenied: "Permission denied"
            case .alreadyExists: "Item already exists"
            case .invalidInput: "Invalid input"
            case .isADirectory: "Item is a directory"
            case .notADirectory: "Item is not a directory"
            case .notASymlink: "Item is not a symlink"
            case .notEmptyDirectory: "Item is not an empty directory"
            case .invalidHandle: "Invalid handle"
            case .noEnoughSpace: "Not enough space"
            case .nameTooLong: "Name too long"
            case .unsupported: "Operation not supported"
            case .arithmeticOverflow: "Arithmetic overflow"
            case .pathResolutionFailed: "Path resolution failed"
            case .peerUnavailable: "Peer is unavailable"
            case .brokenPipe: "Broken pipe"
            case .cancelled: "Operation cancelled"

            case .windowsPermissionDeniedOrIsADirectory: "Permission denied or item is a directory"

            case .unknown: "Unknown error"
        }
    }

}

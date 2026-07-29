

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
        
        case windowsPermissionDeniedOrIsADirectory

        case unknown

    }

    private let kindCases: KindCases

    private init(_ kindCases: KindCases) {
        self.kindCases = kindCases
    }

    public func maybe(_ kind: PlatformErrorKind) -> Bool {
        if self == kind { return true }
        return switch self.kindCases {
            case .windowsPermissionDeniedOrIsADirectory:
                kind.kindCases == .permissionDenied || kind.kindCases == .isADirectory
            default: false
        }
    }

    public static var notFound: PlatformErrorKind { .init(.notFound) }
    public static var permissionDenied: PlatformErrorKind { .init(.permissionDenied) }   
    public static var alreadyExists: PlatformErrorKind { .init(.alreadyExists) } 
    public static var invalidInput: PlatformErrorKind { .init(.invalidInput) }
    public static var isADirectory: PlatformErrorKind { .init(.isADirectory) }       
    public static var notADirectory: PlatformErrorKind { .init(.notADirectory) }
    public static var notASymlink: PlatformErrorKind { .init(.notASymlink) }
    public static var notEmptyDirectory: PlatformErrorKind { .init(.notEmptyDirectory) }
    public static var invalidHandle: PlatformErrorKind { .init(.invalidHandle) }
    public static var noEnoughSpace: PlatformErrorKind { .init(.noEnoughSpace) }
    public static var nameTooLong: PlatformErrorKind { .init(.nameTooLong) } 
    public static var unsupported: PlatformErrorKind { .init(.unsupported) }
    public static var unknown: PlatformErrorKind { .init(.unknown) }
    public static var arithmeticOverflow: PlatformErrorKind { .init(.arithmeticOverflow) }
    public static var pathResolutionFailed: PlatformErrorKind { .init(.pathResolutionFailed) }


    public enum Windows {
        public static var permissionDeniedOrIsADirectory: PlatformErrorKind { .init(.windowsPermissionDeniedOrIsADirectory) }
    }

    public enum Posix {
        // not needed yet
    }


    public static var posix: Posix.Type { Posix.self }
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

            case .windowsPermissionDeniedOrIsADirectory: "Permission denied or item is a directory"

            case .unknown: "Unknown error"
        }
    }

}
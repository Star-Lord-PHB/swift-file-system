import PlatformCLib
import SystemPackage



public enum FsErrorCode: Sendable, Equatable, Hashable {
    case platform(PlatformErrorCode)
    case extended(ExtendedErrorCode)

    public var mappedErrorKind: Kind {
        switch self {
            case .platform(let platformErrorCode): platformErrorCode.mappedErrorKind
            case .extended(let extendedErrorCode): extendedErrorCode.mappedErrorKind
        }
    }

    public var description: String {
        switch self {
            case .platform(let platformErrorCode): platformErrorCode.description
            case .extended(let extendedErrorCode): extendedErrorCode.description
        }
    }

    public var rawValue: CInterop.ErrorCode? {
        switch self {
            case .platform(let platformErrorCode): platformErrorCode.rawValue
            case .extended: nil
        }
    }

    public static var success: FsErrorCode { .platform(.success) }
}



extension FsErrorCode {

    public struct PlatformErrorCode: Sendable, RawRepresentable, CustomStringConvertible {

        #if canImport(WinSDK)
        public static var success: PlatformErrorCode { .init(rawValue: DWORD(ERROR_SUCCESS)) }
        #else
        public static var success: PlatformErrorCode { .init(rawValue: 0) }
        #endif


        public let rawValue: CInterop.ErrorCode


        public init(rawValue: CInterop.ErrorCode) {
            self.rawValue = rawValue
        }

    }

}



extension FsErrorCode.PlatformErrorCode: Equatable, Hashable { }



extension FsErrorCode.PlatformErrorCode {

    @inlinable
    public var description: String {
        #if canImport(WinSDK)
        return errorCodeDescription(for: rawValue) ?? "Unknown error"
        #else
        guard let message = strerror(rawValue) else { return "Unknown error" }
        return String(cString: message)
        #endif
    }


    @inlinable
    public static func fromLastError() -> Self {
        #if canImport(WinSDK)
        return .init(rawValue: GetLastError())
        #else
        return .init(rawValue: errno)
        #endif
    }

}



extension FsErrorCode {

    public enum ExtendedErrorCode: Sendable, Equatable, Hashable {

        // TODO: Add extended error codes here
        case unknown
        case notImplemented


        public var mappedErrorKind: FsErrorCode.Kind {
            switch self {
                case .unknown: .unknown
                case .notImplemented: .unsupported
            }
        }


        public var description: String {
            switch self {
                case .unknown: "Unknown error"
                case .notImplemented: "Functionality not implemented by Swift FileSystem at library level"
            }
        }

    }

}



extension FsErrorCode {

    public static var fileNotFound: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.fileNotFound)
        #else
        return .platform(.noSuchFileOrDirectory)
        #endif
    }

    public static var permissionDenied: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.accessDenied)
        #else
        return .platform(.permissionDenied)
        #endif
    }

    public static var fileExists: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.fileExists)
        #else
        return .platform(.fileExists)
        #endif
    }

    public static var notADirectory: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.invalidDirectoryName)
        #else
        return .platform(.notADirectory)
        #endif
    }

    public static var isADirectory: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.accessDenied)
        #else
        return .platform(.isADirectory)
        #endif
    }

    public static var directoryNotEmpty: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.directoryNotEmpty)
        #else
        return .platform(.directoryNotEmpty)
        #endif
    }

    public static var invalidHandle: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.invalidHandle)
        #else
        return .platform(.badFileDescriptor)
        #endif
    }

    public static var noEnoughSpace: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.diskFull)
        #else
        return .platform(.noSpaceLeftOnDevice)
        #endif
    }

    public static var notSupported: FsErrorCode {
        #if canImport(WinSDK)
        return .platform(.notSupported)
        #else
        return .platform(.operationNotSupported)
        #endif
    }

    public static var unknown: FsErrorCode {
        .extended(.unknown)
    }

}



extension FsErrorCode {

    public enum Kind: Sendable, Equatable, Hashable {

        case notFound
        case permissionDenied
        case alreadyExists
        case invalidInput
        case isADirectory
        case notADirectory
        case notEmptyDirectory
        case invalidHandle
        case noEnoughSpace
        case nameTooLong
        case unsupported

        case unknown

    }

}



extension FsErrorCode.Kind {

    public init(mapping extendedErrorCode: FsErrorCode.ExtendedErrorCode) {
        self = extendedErrorCode.mappedErrorKind
    }


    public init(mapping platformErrorCode: FsErrorCode.PlatformErrorCode) {
        self = platformErrorCode.mappedErrorKind
    }


    public init(mapping errorCode: FsErrorCode) {
        self = errorCode.mappedErrorKind
    }

}
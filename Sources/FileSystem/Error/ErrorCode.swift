import PlatformCLib


public struct PlatformErrorCode: Sendable, RawRepresentable, CustomStringConvertible {

    #if canImport(WinSDK)
    public typealias RawBitType = DWORD
    public static var success: PlatformErrorCode { .init(rawValue: ERROR_SUCCESS) }
    #else
    public typealias RawBitType = CInt
    public static var success: PlatformErrorCode { .init(rawValue: 0) }
    #endif


    public let rawValue: RawBitType


    public init(rawValue: RawBitType) {
        self.rawValue = rawValue
    }

}



extension PlatformErrorCode: Equatable, Hashable { }



extension PlatformErrorCode {

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
    public static func fromLastError() -> PlatformErrorCode {
        #if canImport(WinSDK)
        return .init(rawValue: GetLastError())
        #else
        return .init(rawValue: errno)
        #endif
    }

}



public enum ExtendedErrorCode: Sendable, Equatable, Hashable {

    // TODO: Add extended error codes here
    case unknown


    public var mappedErrorKind: ErrorCode.Kind {
        switch self {
            case .unknown: .unknown
        }
    }


    public var description: String {
        switch self {
            case .unknown: "Unknown error"
        }
    }

}



public enum ErrorCode: Sendable, Equatable, Hashable {
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

    public var rawValue: PlatformErrorCode.RawBitType? {
        switch self {
            case .platform(let platformErrorCode): platformErrorCode.rawValue
            case .extended: nil
        }
    }

    public static var success: ErrorCode { .platform(.success) }
}



extension ErrorCode {

    public static var fileNotFound: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.fileNotFound)
        #else
        return .platform(.noSuchFileOrDirectory)
        #endif
    }

    public static var permissionDenied: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.accessDenied)
        #else
        return .platform(.permissionDenied)
        #endif
    }

    public static var fileExists: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.fileExists)
        #else
        return .platform(.fileExists)
        #endif
    }

    public static var notADirectory: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.directory)
        #else
        return .platform(.notADirectory)
        #endif
    }

    public static var isADirectory: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.accessDenied)
        #else
        return .platform(.isADirectory)
        #endif
    }

    public static var directoryNotEmpty: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.directoryNotEmpty)
        #else
        return .platform(.directoryNotEmpty)
        #endif
    }

    public static var invalidHandle: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.invalidHandle)
        #else
        return .platform(.badFileDescriptor)
        #endif
    }

    public static var noEnoughSpace: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.diskFull)
        #else
        return .platform(.noSpaceLeftOnDevice)
        #endif
    }

    public static var notSupported: ErrorCode {
        #if canImport(WinSDK)
        return .platform(.notSupported)
        #else
        return .platform(.operationNotSupported)
        #endif
    }

    public static var unknown: ErrorCode {
        .extended(.unknown)
    }

}



extension ErrorCode {

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



extension ErrorCode.Kind {

    public init(mapping extendedErrorCode: ExtendedErrorCode) {
        self = extendedErrorCode.mappedErrorKind
    }


    public init(mapping platformErrorCode: PlatformErrorCode) {
        self = platformErrorCode.mappedErrorKind
    }


    public init(mapping errorCode: ErrorCode) {
        self = errorCode.mappedErrorKind
    }

}
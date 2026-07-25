import PlatformCLib



public enum PlatformErrorCode: Sendable, Equatable, Hashable {
    case system(SystemErrorCode)
    case extended(ExtendedErrorCode)

    public var mappedErrorKind: Kind {
        switch self {
            case .system(let systemErrorCode): systemErrorCode.mappedErrorKind
            case .extended(let extendedErrorCode): extendedErrorCode.mappedErrorKind
        }
    }

    public var description: String {
        switch self {
            case .system(let systemErrorCode): systemErrorCode.description
            case .extended(let extendedErrorCode): extendedErrorCode.description
        }
    }

    public var rawValue: PlatformInteropTypes.ErrorCode? {
        switch self {
            case .system(let systemErrorCode): systemErrorCode.rawValue
            case .extended: nil
        }
    }

    public static var success: PlatformErrorCode { .system(.success) }
}



extension PlatformErrorCode {

    public struct SystemErrorCode: Sendable, RawRepresentable, CustomStringConvertible {

        #if canImport(WinSDK)
        public static var success: SystemErrorCode { .init(rawValue: DWORD(ERROR_SUCCESS)) }
        #else
        public static var success: SystemErrorCode { .init(rawValue: 0) }
        #endif


        public let rawValue: PlatformInteropTypes.ErrorCode


        public init(rawValue: PlatformInteropTypes.ErrorCode) {
            self.rawValue = rawValue
        }

    }

}



extension PlatformErrorCode.SystemErrorCode: Equatable, Hashable { }



extension PlatformErrorCode.SystemErrorCode {

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



extension PlatformErrorCode {

    public enum ExtendedErrorCode: Sendable, Equatable, Hashable {

        // TODO: Add extended error codes here
        case unknown
        case notImplemented


        public var mappedErrorKind: PlatformErrorCode.Kind {
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



extension PlatformErrorCode {

    public static var fileNotFound: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.fileNotFound)
        #else
        return .system(.noSuchFileOrDirectory)
        #endif
    }

    public static var permissionDenied: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.accessDenied)
        #else
        return .system(.permissionDenied)
        #endif
    }

    public static var fileExists: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.fileExists)
        #else
        return .system(.fileExists)
        #endif
    }

    public static var notADirectory: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.invalidDirectoryName)
        #else
        return .system(.notADirectory)
        #endif
    }

    public static var isADirectory: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.accessDenied)
        #else
        return .system(.isADirectory)
        #endif
    }

    public static var directoryNotEmpty: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.directoryNotEmpty)
        #else
        return .system(.directoryNotEmpty)
        #endif
    }

    public static var invalidHandle: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.invalidHandle)
        #else
        return .system(.badFileDescriptor)
        #endif
    }

    public static var noEnoughSpace: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.diskFull)
        #else
        return .system(.noSpaceLeftOnDevice)
        #endif
    }

    public static var notSupported: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.notSupported)
        #else
        return .system(.operationNotSupported)
        #endif
    }

    public static var invalidInput: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.badArguments)
        #else
        return .system(.invalidArgument)
        #endif
    }

    public static var arithmeticOverflow: PlatformErrorCode {
        #if canImport(WinSDK)
        return .system(.arithmeticOverflow)
        #else
        return .system(.valueTooLarge)
        #endif
    }

    public static var unknown: PlatformErrorCode {
        .extended(.unknown)
    }

}



extension PlatformErrorCode {

    public struct Kind: Sendable, Equatable, Hashable {

        private enum KindCases: Sendable, Equatable, Hashable {

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
            case arithmeticOverflow

            case unknown

        }

        private let kindCases: KindCases

        private init(_ kindCases: KindCases) {
            self.kindCases = kindCases
        }

        public static var notFound: Kind { .init(.notFound) }
        public static var permissionDenied: Kind { .init(.permissionDenied) }   
        public static var alreadyExists: Kind { .init(.alreadyExists) } 
        public static var invalidInput: Kind { .init(.invalidInput) }
        public static var isADirectory: Kind { .init(.isADirectory) }       
        public static var notADirectory: Kind { .init(.notADirectory) }
        public static var notEmptyDirectory: Kind { .init(.notEmptyDirectory) }
        public static var invalidHandle: Kind { .init(.invalidHandle) }
        public static var noEnoughSpace: Kind { .init(.noEnoughSpace) }
        public static var nameTooLong: Kind { .init(.nameTooLong) } 
        public static var unsupported: Kind { .init(.unsupported) }
        public static var unknown: Kind { .init(.unknown) }
        public static var arithmeticOverflow: Kind { .init(.arithmeticOverflow) }

    }

}



extension PlatformErrorCode.Kind {

    public init(mapping extendedErrorCode: PlatformErrorCode.ExtendedErrorCode) {
        self = extendedErrorCode.mappedErrorKind
    }


    public init(mapping systemErrorCode: PlatformErrorCode.SystemErrorCode) {
        self = systemErrorCode.mappedErrorKind
    }


    public init(mapping errorCode: PlatformErrorCode) {
        self = errorCode.mappedErrorKind
    }

}

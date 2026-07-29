import PlatformCLib



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



extension SystemErrorCode: Equatable, Hashable { }



extension SystemErrorCode {

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

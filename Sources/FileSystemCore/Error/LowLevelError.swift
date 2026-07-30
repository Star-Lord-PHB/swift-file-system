import PlatformCLib


public struct LowLevelError: Error {

    public static let successCode: PlatformInteropTypes.ErrorCode = SystemErrorCode.success.rawValue

    public let systemCode: SystemErrorCode?
    public let kind: PlatformErrorKind

    public init?(rawSystemCode: PlatformInteropTypes.ErrorCode?, kind: PlatformErrorKind? = nil) {
        self.init(systemCode: rawSystemCode.map { .init(rawValue: $0) }, kind: kind)
    }

    public init?(systemCode: SystemErrorCode?, kind: PlatformErrorKind? = nil) {
        guard systemCode != .success else { return nil }
        self.systemCode = systemCode
        self.kind = kind ?? systemCode?.defaultMappedErrorKind ?? .unknown
    }

    public init(kind: PlatformErrorKind) {
        self.systemCode = nil
        self.kind = kind
    }

    package func overridingKind(_ kind: PlatformErrorKind) -> LowLevelError {
        .init(systemCode: systemCode, kind: kind)!
    }

    public static func fromLastError() -> LowLevelError? {
        #if canImport(WinSDK)
        return .init(rawSystemCode: GetLastError())
        #else
        return .init(rawSystemCode: errno)
        #endif
    }

    public static func check() throws(LowLevelError) {
        guard let error = fromLastError() else { return }
        throw error
    }

    public static func assertError(fallbackToUnknownError: Bool = false) throws(LowLevelError) -> Never {
        try check()
        if fallbackToUnknownError {
            throw .unknown
        }
        fatalError("Expect to catch an error, but none was thrown")
    }

}



extension LowLevelError: Equatable, Hashable {}



extension LowLevelError: CustomStringConvertible {

    @inlinable
    public var description: String {
        if let systemCode {
            "\(kind.description) (systemCode: \(systemCode.rawValue))"
        } else {
            kind.description
        }
    }

    @inlinable
    public var errorDescription: String { description }

}



extension LowLevelError {

    public static var unknown: LowLevelError { .init(kind: .unknown) }

}

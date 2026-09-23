import PlatformCLib


/// Platform-specific low-level error type.
public struct LowLevelError: Error {

    /// The system error code representing success.
    public static let successCode: PlatformInteropTypes.ErrorCode = SystemErrorCode.success.rawValue

    /// The system error code associated with this error, if any.
    public let systemCode: SystemErrorCode?
    /// The cross-platform semantic kind of this error.
    public let kind: PlatformErrorKind

    /// Creates a new instance from a native error code and a semantic kind.
    /// - Parameters:
    ///   - rawSystemCode: The native error code.
    ///   - kind: The semantic kind of the error.
    /// 
    /// If none of the `rawSystemCode` or `kind` are provided, the result will be an ``unknown`` error.
    /// 
    /// If the `rawSystemCode` is provided while the `kind` is not, the `kind` will be inferred from 
    /// the provided `rawSystemCode`.
    /// 
    /// If the `rawSystemCode` is the succes code, the result will be `nil`.
    public init?(rawSystemCode: PlatformInteropTypes.ErrorCode?, kind: PlatformErrorKind? = nil) {
        self.init(systemCode: rawSystemCode.map { .init(rawValue: $0) }, kind: kind)
    }

    /// Creates a new instance from a system error code and a semantic kind.
    /// - Parameters:
    ///   - systemCode: The system error code.
    ///   - kind: The semantic kind of the error.
    /// 
    /// If none of the `systemCode` or `kind` are provided, the result will be an ``unknown`` error.
    /// 
    /// If the `systemCode` is provided while the `kind` is not, the `kind` will be inferred from 
    /// the provided `systemCode`.
    /// 
    /// If the `systemCode` is the succes code, the result will be `nil`.
    public init?(systemCode: SystemErrorCode?, kind: PlatformErrorKind? = nil) {
        guard systemCode != .success else { return nil }
        self.systemCode = systemCode
        self.kind = kind ?? systemCode?.defaultMappedErrorKind ?? .unknown
    }

    /// Creates a new instance from a semantic kind without a system error code.
    /// - Parameter kind: The semantic kind of the error.
    public init(kind: PlatformErrorKind) {
        self.systemCode = nil
        self.kind = kind
    }

    package func overridingKind(_ kind: PlatformErrorKind) -> LowLevelError {
        .init(systemCode: systemCode, kind: kind)!
    }

    /// Creates a ``LowLevelError`` from the last reported error code of the current thread, or `nil` 
    /// if no error was reported.
    public static func fromLastError() -> LowLevelError? {
        #if canImport(WinSDK)
        return .init(rawSystemCode: GetLastError())
        #else
        return .init(rawSystemCode: errno)
        #endif
    }

    /// Checks the last reported error code of the current thread, and throws a ``LowLevelError`` if 
    /// an error was reported.
    public static func check() throws(LowLevelError) {
        guard let error = fromLastError() else { return }
        throw error
    }

    /// Asserts that there was an error reported in the current thread and throws a ``LowLevelError``
    /// - Parameter fallbackToUnknownError: If `true`, throw an ``unknown`` error if no error was reported. 
    ///                                     If `false`, crash the process if no error was reported.
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

    /// The ``LowLevelError`` representing an unknown error.
    public static var unknown: LowLevelError { .init(kind: .unknown) }

}

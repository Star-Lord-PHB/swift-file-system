import PlatformCLib


public struct SystemError: Error, Equatable, CustomStringConvertible {

    public typealias Code = PlatformInteropTypes.ErrorCode
    public static let successCode: Code = PlatformErrorCode.SystemErrorCode.success.rawValue

    public let code: PlatformErrorCode

    public var kind: PlatformErrorCode.Kind { code.mappedErrorKind }

    public init?(code: Code) {
        self.init(code: .system(.init(rawValue: code)))
    }

    public init?(code: PlatformErrorCode) {
        guard code != .success else { return nil }
        self.code = code
    }

    @inlinable
    public var description: String { code.description }

    @inlinable
    public var errorDescription: String { description }

    public static func fromLastError() -> SystemError? {
        #if canImport(WinSDK)
        return .init(code: GetLastError())
        #else
        return .init(code: errno)
        #endif
    }

    public static func check() throws(SystemError) {
        guard let error = fromLastError() else { return }
        throw error
    }

    public static func assertError(fallbackToUnknownError: Bool = false) throws(SystemError) -> Never {
        try check()
        if fallbackToUnknownError {
            throw .init(code: .extended(.unknown))!
        }
        fatalError("Expect to catch an error, but none was thrown")
    }

}

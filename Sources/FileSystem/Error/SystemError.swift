import PlatformCLib
import SystemPackage


public struct SystemError: Error, Equatable, CustomStringConvertible {

    public typealias Code = CInterop.ErrorCode
    public static let successCode: Code = FsErrorCode.PlatformErrorCode.success.rawValue

    public let code: FsErrorCode

    public var kind: FsErrorCode.Kind { code.mappedErrorKind }

    public init?(code: Code) {
        self.init(code: .platform(.init(rawValue: code)))
    }

    public init?(code: FsErrorCode) {
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
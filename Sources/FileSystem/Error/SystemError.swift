import PlatformCLib


public struct SystemError: Error, Equatable, CustomStringConvertible {

    #if canImport(WinSDK)
    public typealias Code = DWORD
    public static let successCode: Code = .init(ERROR_SUCCESS)
    #else
    public typealias Code = CInt
    public static let successCode: Code = 0
    #endif

    public let code: Code

    @inlinable
    public var description: String {
        #if canImport(WinSDK)
        return errorCodeDescription(for: code) ?? "Unknown error"
        #else
        guard let message = strerror(code) else { return "Unknown error" }
        return String(cString: message)
        #endif
    }

    @inlinable
    public var errorDescription: String { description }

    public static let success: SystemError = .init(code: successCode)

    public static func fromLastError() -> SystemError {
        #if canImport(WinSDK)
        return .init(code: GetLastError())
        #else
        return .init(code: errno)
        #endif
    }

    public static func check() throws(SystemError) {
        let error = fromLastError()
        guard error != success else { return }
        throw error
    }

    public static func assertError() throws(SystemError) -> Never {
        try check()
        fatalError("Expect to catch an error, but none was thrown")
    }

}
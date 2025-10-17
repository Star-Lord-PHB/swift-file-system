import Foundation

#if canImport(WinSDK)
import WinSDK
#endif


struct SystemError: Error, Equatable {

    #if canImport(WinSDK)
    typealias Code = DWORD
    static let successCode: Code = .init(ERROR_SUCCESS)
    #else
    typealias Code = CInt
    static let successCode: Code = 0
    #endif

    let code: Code

    static let success: SystemError = .init(code: successCode)

    static func fromLastError() -> SystemError {
        #if canImport(WinSDK)
        return .init(code: GetLastError())
        #else
        return .init(code: errno)
        #endif
    }

    static func check() throws(SystemError) {
        let error = fromLastError()
        guard error != success else { return }
        throw error
    }

    static func assertError() throws(SystemError) -> Never {
        try check()
        fatalError("Expect to catch an error, but none was thrown")
    }

}
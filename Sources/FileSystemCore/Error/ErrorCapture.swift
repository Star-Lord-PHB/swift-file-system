#if canImport(WinSDK)
import WinSDK
#endif 


package func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: (CInt) throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError(errorCode)
        return
    }
}


#if canImport(WinSDK)
package func execThrowingCFunction<E: Error>(_ function: () -> DWORD, onError: (DWORD) throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError(errorCode)
        return
    }
}
#endif 


package func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: () throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError()
        return
    }
}


package func execThrowingCFunction<E: Error>(_ function: () -> Bool, onError: () throws(E) -> Void) throws(E) {
    let success = function()
    guard success else {
        try onError()
        return
    }
}


@inlinable
package func execThrowingCFunction(_ function: () -> CInt) throws(SystemError) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try SystemError.assertError()
    }
}


package func execThrowingCFunction(_ function: () -> Bool) throws(SystemError) {
    let success = function()
    guard success else {
        try SystemError.assertError()
    }
}


package func execThrowingCFunction(operation: @autoclosure () -> PlatformError.Operation, _ function: () -> CInt) throws(PlatformError) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try PlatformError.assertError(operation: operation())
    }
}


package func execThrowingCFunction(operation: @autoclosure () -> PlatformError.Operation, _ function: () -> Bool) throws(PlatformError) {
    let success = function()
    guard success else {
        try PlatformError.assertError(operation: operation())
    }
}


@inlinable
package func catchSystemError<R: ~Copyable>(
    operation: @autoclosure () -> PlatformError.Operation, 
    _ function: () throws(SystemError) -> R
) throws(PlatformError) -> R {

    do {
        return try function()
    } catch {
        throw .init(systemError: error, operation: operation())
    }

}
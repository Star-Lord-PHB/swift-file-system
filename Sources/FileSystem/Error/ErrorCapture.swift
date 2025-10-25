import Foundation

#if canImport(WinSDK)
import WinSDK
#endif 


func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: (CInt) throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError(errorCode)
        return
    }
}


#if canImport(WinSDK)
func execThrowingCFunction<E: Error>(_ function: () -> DWORD, onError: (DWORD) throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError(errorCode)
        return
    }
}
#endif 


func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: () throws(E) -> Void) throws(E) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try onError()
        return
    }
}


func execThrowingCFunction<E: Error>(_ function: () -> Bool, onError: () throws(E) -> Void) throws(E) {
    let success = function()
    guard success else {
        try onError()
        return
    }
}


func execThrowingCFunction(_ function: () -> CInt) throws(SystemError) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        throw .fromLastError()
    }
}


func execThrowingCFunction(_ function: () -> Bool) throws(SystemError) {
    let success = function()
    guard success else {
        throw .fromLastError()
    }
}


func execThrowingCFunction(operationDescription: FileError.OperationDescription, _ function: () -> CInt) throws(FileError) {
    let errorCode = function()
    guard errorCode == SystemError.successCode else {
        try FileError.assertError(operationDescription: operationDescription)
    }
}


func execThrowingCFunction(operationDescription: FileError.OperationDescription, _ function: () -> Bool) throws(FileError) {
    let success = function()
    guard success else {
        try FileError.assertError(operationDescription: operationDescription)
    }
}


func catchSystemError<R: ~Copyable>(
    operationDescription: FileError.OperationDescription, 
    _ function: () throws(SystemError) -> R
) throws(FileError) -> R {

    do {
        return try function()
    } catch {
        throw .init(code: .init(rawValue: error.code), operationDescription: operationDescription)
    }

}
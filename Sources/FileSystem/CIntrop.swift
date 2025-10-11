import Foundation


func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: (CInt) -> E?) throws(E) {
    let errorCode = function()
    guard errorCode == 0 else {
        if let error = onError(errorCode) { throw error }
        return
    }
}


func execThrowingCFunction<E: Error>(_ function: () -> CInt, onError: () -> E?) throws(E) {
    let errorCode = function()
    guard errorCode == 0 else {
        if let error = onError() { throw error }
        return
    }
}


func assertExecThrowingCFunction(_ function: () -> CInt) {
    let errorCode = function()
    guard errorCode == 0 else {
        fatalError("TODO: \(errno)")
    }
}
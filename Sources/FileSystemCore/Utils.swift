import PlatformCLib
import SystemPackage


/// Used for checking potential resource leak
package func currentOpenedHandleCount() -> Int64 {

    #if canImport(WinSDK)

    var count = 0 as DWORD
    GetProcessHandleCount(GetCurrentProcess(), &count)
    return Int64(count)

    #elseif canImport(Darwin)

    return Int64(Int(proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)) / MemoryLayout<proc_fdinfo>.size)

    #else

    var count = 0 as Int64
    let procFdDir = opendir("/proc/self/fd")!
    defer { closedir(procFdDir) }
    while readdir(procFdDir) != nil {
        count += 1
    }
    return count - 2

    #endif

}



extension String {

    package func withCStringTypedThrow<R: ~Copyable, Encoding: _UnicodeEncoding, E: Error>(encodedAs encoding: Encoding.Type, _ body: (UnsafePointer<Encoding.CodeUnit>) throws(E) -> R) throws(E) -> R {
        do {
            var result: R?
            try self.withCString(encodedAs: encoding) { ptr in 
                result = try body(ptr)
            }
            return result!
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }

}



extension FilePath {

    package func withPlatformStringTypedThrow<R: ~Copyable, E: Error>(_ body: (UnsafePointer<CInterop.PlatformChar>) throws(E) -> R) throws(E) -> R {
        do {
            var result: R?
            try self.withPlatformString { ptr in 
                result = try body(ptr)
            }
            return result!
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }

}



package func withUnsafeOptionalPointer<V: ~Copyable, R: ~Copyable, E: Error>(
    to value: borrowing V?, 
    _ body: (UnsafePointer<V>?) throws(E) -> R
) throws(E) -> R {
    switch value {
        case .some(let v):
            return try withUnsafePointer(to: v) { (ptr) throws(E) in 
                try body(ptr)
            }
        case .none:
            return try body(nil)
    }
}

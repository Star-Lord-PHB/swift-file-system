import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif 


/// Used for checking potential resource leak
func currentOpenedHandleCount() -> Int64 {

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



extension ContiguousBytes {

    func withUnsafeBytesTypedThrow<R: ~Copyable, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        do {
            var result: R?
            try self.withUnsafeBytes { bufferPtr in
                result = try body(bufferPtr)
            }
            return result!
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }

}



extension String {

    func withCStringTypedThrow<R: ~Copyable, Encoding: _UnicodeEncoding, E: Error>(encodedAs encoding: Encoding.Type, _ body: (UnsafePointer<Encoding.CodeUnit>) throws(E) -> R) throws(E) -> R {
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

    func withPlatformStringTypedThrow<R: ~Copyable, E: Error>(_ body: (UnsafePointer<CInterop.PlatformChar>) throws(E) -> R) throws(E) -> R {
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
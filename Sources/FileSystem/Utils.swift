import Foundation

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

    func withUnsafeBytesTypedThrow<R, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        do {
            return try self.withUnsafeBytes { bufferPtr in
                try body(bufferPtr) 
            }
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }

}
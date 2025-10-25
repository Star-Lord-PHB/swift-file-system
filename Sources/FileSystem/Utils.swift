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

    return Int(proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)) / MemoryLayout<proc_fdinfo>.size

    #else

    var count = 0 as Int64
    let procFdDir = #require(opendir("/proc/self/fd"))
    defer { closedir(procFdDir) }
    while readdir(procFdDir) != nil {
        count += 1
    }
    return count - 2

    #endif

}
#if !canImport(WinSDK) 
import PlatformCLib
import SystemPackage



extension InternalFS {

    static func utimens(for path: FilePath, times: (FileTimeSpec, FileTimeSpec)) throws(SystemError) {
        let platformTimes = (times.0.platformFileTime, times.1.platformFileTime)
        try execThrowingCFunction {
            withUnsafePointer(to: platformTimes) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    path.withPlatformString { pathPtr in 
                        utimensat(AT_FDCWD, pathPtr, reboundPtr, AT_SYMLINK_NOFOLLOW)
                    }
                }
            }
        }
    }


    static func makeFifo(
        at path: FilePath, 
        permission: FilePermissions = [.ownerReadWrite, .groupRead, .otherRead]
    ) throws(SystemError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                mkfifo(pathPtr, permission.rawValue)
            }
        }
    }


    static func ulstat(_ path: FilePath) throws(SystemError) -> CInterop.Stat {

        var st = CInterop.Stat.PlatformStat()

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                lstat(pathPtr, &st)
            }
        }
        #else
        try execThrowingCFunction {
            systemStatCompat(path.string, AT_SYMLINK_NOFOLLOW, &st)
        }
        #endif

        return .init(platformStat: st)

    }

}
#endif
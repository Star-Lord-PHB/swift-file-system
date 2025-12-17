import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    /// A direct wrapper of the stat structure of each platform.
    /// 
    /// Mainly aimed at providing relative uniform access to the properties and eliminating 
    /// the name differences between platforms. 
    /// 
    /// However, this type does not works very well on Windows due to limited support of stat 
    /// structure on Windows. It does works, but most of the properties may not be meaningful. 
    /// For example, all the file time properties are represented as a single Int64 value 
    /// instead of a FILETIME structure while creation time is not provided at all. Thus on 
    /// Windows, it is just provided to support the unified stat function call, but not for 
    /// serious file metadata access. For that, use the ``InternalFS/InternalRawFileInfo`` type
    struct Stat {

        #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        typealias PlatformStat = stat
        #else 
        typealias PlatformStat = StatCompat
        #endif

        #if canImport(WinSDK)
        typealias Time = Int64
        #else 
        typealias Time = timespec
        #endif

        let platformStat: PlatformStat

        var st_dev: UInt32 { .init(platformStat.st_dev) }
        var st_ino: UInt64 { .init(platformStat.st_ino) }
        var st_mode: mode_t { .init(platformStat.st_mode) }
        var st_nlink: UInt32 { .init(platformStat.st_nlink) }
        var st_uid: UInt32 { platformStat.st_uid }
        var st_gid: UInt32 { platformStat.st_gid }
        var st_rdev: UInt32 { .init(platformStat.st_rdev) }
        var st_size: UInt64 { .init(platformStat.st_size) }

        var st_atim: Time {
            #if canImport(WinSDK)
            return platformStat.st_atime
            #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
            return platformStat.st_atimespec
            #else
            return platformStat.st_atim
            #endif
        }

        var st_mtim: Time {
            #if canImport(WinSDK)
            return platformStat.st_mtime
            #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
            return platformStat.st_mtimespec
            #else
            return platformStat.st_mtim
            #endif
        }

        var st_ctim: Time {
            #if canImport(WinSDK)
            return platformStat.st_ctime
            #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
            return platformStat.st_ctimespec
            #else
            return platformStat.st_ctim
            #endif
        }

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        var st_btim: Time {
            return platformStat.st_birthtimespec
        }
        #elseif !canImport(WinSDK)
        var st_btim: Time? {
            return platformStat.has_btime != 0 ? platformStat.st_btim : nil
        }
        #endif

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        var st_flags: UInt32 {
            return platformStat.st_flags
        }
        #elseif !canImport(WinSDK)
        var st_attributes: UInt64 {
            return platformStat.st_attributes
        }
        var st_attributes_mask: UInt64 {
            return platformStat.st_attributes_mask
        }
        #endif

        init(platformStat: PlatformStat = .init()) {
            self.platformStat = platformStat
        }

    }


    static func ustat(_ path: FilePath) throws(SystemError) -> Stat {

        var st = Stat.PlatformStat()

        #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                stat(pathPtr, &st)
            }
        }
        #else
        try execThrowingCFunction {
            systemStatCompat(path.string, 0, &st)
        }
        #endif

        return .init(platformStat: st)

    }


    #if !canImport(WinSDK)

    static func ulstat(_ path: FilePath) throws(SystemError) -> Stat {

        var st = Stat.PlatformStat()

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


    static func ufstat(_ handle: borrowing UnsafeSystemHandle) throws(SystemError) -> Stat {

        var st = Stat.PlatformStat()

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            fstat(handle.unsafeRawHandle, &st)
        }
        #else
        try execThrowingCFunction {
            systemFStatCompat(handle.unsafeRawHandle, &st)
        }
        #endif

        return .init(platformStat: st)

    }

    #endif 

}
import SystemPackage
import PlatformCLib



extension CInterop {

    #if canImport(WinSDK)
    public typealias PlatformFileTime = FILETIME
    #else
    public typealias PlatformFileTime = timespec
    #endif


    #if canImport(Glibc) || canImport(Musl)
    public typealias PlatformFileAttribute = UInt64
    #elseif canImport(WinSDK)
    public typealias PlatformFileAttribute = DWORD
    #else 
    public typealias PlatformFileAttribute = UInt32
    #endif


    #if !canImport(WinSDK)
    public typealias PosixInodeFlags = CInt
    #endif

    #if canImport(WinSDK)
    public typealias FileId = UInt128
    public typealias DeviceId = UInt64
    #else
    public typealias FileId = UInt64
    public typealias DeviceId = UInt32
    #endif 

    #if canImport(WinSDK)
    public typealias ErrorCode = DWORD
    #else
    public typealias ErrorCode = CInt
    #endif


    /// A direct wrapper of the stat structure of each platform.
    /// 
    /// Mainly aimed at providing relative uniform access to the properties and eliminating 
    /// the name differences between platforms. 
    /// 
    /// However, this type does not works very well on Windows due to limited support of stat 
    /// structure on Windows. It does works, but most of the properties may not be meaningful. 
    /// Thus on Windows, it is just provided to support the unified stat function call, but not 
    /// for serious file metadata access. For that, use the ``InternalFS/InternalRawFileInfo`` type
    struct Stat {

        #if canImport(WinSDK)
        typealias PlatformStat = _stat64
        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        typealias PlatformStat = stat
        #else 
        typealias PlatformStat = StatCompat
        #endif

        #if canImport(WinSDK)
        typealias Time = Int64
        #else 
        typealias Time = timespec
        #endif

        #if canImport(WinSDK)
        typealias mode_t = UInt16
        #endif

        let platformStat: PlatformStat

        var st_dev: UInt32 { .init(platformStat.st_dev) }
        var st_ino: UInt64 { .init(platformStat.st_ino) }
        var st_mode: mode_t { .init(platformStat.st_mode) }
        var st_nlink: UInt32 { .init(platformStat.st_nlink) }
        var st_rdev: UInt32 { .init(platformStat.st_rdev) }
        var st_size: UInt64 { .init(platformStat.st_size) }

        #if !canImport(WinSDK)
        var st_uid: UInt32 { platformStat.st_uid }
        var st_gid: UInt32 { platformStat.st_gid }
        #endif 

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
        var st_flags: UInt64 {
            return platformStat.st_attributes
        }
        var st_flags_mask: UInt64 {
            return platformStat.st_attributes_mask
        }
        #endif

        init(platformStat: PlatformStat = .init()) {
            self.platformStat = platformStat
        }

    }

}
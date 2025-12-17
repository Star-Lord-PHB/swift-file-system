import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    struct InternalRawFileInfo {

        public typealias PlatformFileTime = timespec

        let type: FileInfo.FileType
        let size: UInt64
        let fileId: UInt64
        let deviceId: UInt32

        let accessTime: CInterop.PlatformFileTime
        let modificationTime: CInterop.PlatformFileTime
        let changeTime: CInterop.PlatformFileTime
        #if canImport(Darwin) || canImport(WinSDK) || os(FreeBSD) || os(OpenBSD)
        let creationTime: CInterop.PlatformFileTime
        #else 
        let creationTime: CInterop.PlatformFileTime?
        #endif

        let attributes: CInterop.PlatformFileAttribute

        #if !canImport(Darwin) && !canImport(WinSDK) && !os(FreeBSD) && !os(OpenBSD)
        let supportedAttributes: CInterop.PlatformFileAttribute
        #endif

        #if canImport(WinSDK)
        let effectiveAccess: ACCESS_MASK?
        #else
        let permissions: FilePermissions
        let uid: UInt32
        let gid: UInt32
        #endif

    }


    static func getRawFileInfo(forItemAt path: FilePath, followSymlink: Bool = false) throws(SystemError) -> InternalRawFileInfo {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        let st = if followSymlink {
            try ustat(path)
        } else {
            try ulstat(path)
        }

        return .init(from: st)

        #endif 

    }


    static func getRawFileInfo(from handle: borrowing UnsafeSystemHandle) throws(SystemError) -> InternalRawFileInfo {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        return .init(from: try ufstat(handle))

        #endif 

    }

}



extension InternalFS.InternalRawFileInfo {

    #if !canImport(WinSDK)
    init(from stat: InternalFS.Stat) {
        self.type = .init(mode: stat.st_mode)
        self.size = .init(stat.st_size)
        self.fileId = stat.st_ino
        self.deviceId = .init(stat.st_dev)
        self.accessTime = stat.st_atim
        self.modificationTime = stat.st_mtim
        self.changeTime = stat.st_ctim

        self.creationTime = stat.st_btim

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        self.attributes = stat.st_flags
        #else 
        self.attributes = stat.st_attributes
        self.supportedAttributes = stat.st_attributes_mask
        #endif

        self.permissions = .init(rawValue: stat.st_mode & 0o7777)
        self.uid = stat.st_uid
        self.gid = stat.st_gid
    }
    #endif 

}



// MARK: - Times
extension InternalFS {

    static func setFileTimes(
        forItemAt path: FilePath, 
        access: CInterop.PlatformFileTime?, 
        modification: CInterop.PlatformFileTime?,
        creation: CInterop.PlatformFileTime? = nil
    ) throws(SystemError) {

        if access == nil && modification == nil && creation == nil { return }

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        // MARK: TODO: on Darwin, use setattrlist to set the three times in one syscall

        let access = access ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))

        var times = (access, timespec())

        if let creation {
            times.1 = creation
            try self.utimens(for: path, times: times)
        }

        guard creation == nil || modification != nil else {
            // the next call is only necessary when creation time is not set or modification time need to be set
            return
        }

        times.1 = modification ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))

        try self.utimens(for: path, times: times)

        #else 

        var times = (
            access ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT)), 
            modification ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))
        )

        try self.utimens(for: path, times: times)

        #endif 

    }


    static func setFileTimes(
        for handle: borrowing UnsafeSystemHandle, 
        access: CInterop.PlatformFileTime?, 
        modification: CInterop.PlatformFileTime?,
        creation: CInterop.PlatformFileTime? = nil
    ) throws(SystemError) {

        if access == nil && modification == nil && creation == nil { return }

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        let access = access ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))
        var times = (access, timespec())

        if let creation {
            times.1 = creation
            try self.futimens(for: handle, times: times)
        }

        times.1 = modification ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))

        try self.futimens(for: handle, times: times)

        #else 

        var times = (
            access ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT)),
            modification ?? timespec(tv_sec: 0, tv_nsec: .init(UTIME_OMIT))
        )

        try self.futimens(for: handle, times: times)

        #endif 

    }

}



// MARK: - Attributes & Flags
extension InternalFS {

    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    static func setFileAttributes(forItemAt path: FilePath, attributes: CInterop.PlatformFileAttribute) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                lchflags(pathPtr, attributes)
            }
        }

        #endif 

    }


    static func setFileAttributes(for handle: borrowing UnsafeSystemHandle, attributes: CInterop.PlatformFileAttribute) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try execThrowingCFunction {
            fchflags(handle.unsafeRawHandle, attributes)
        }

        #endif 

    }

    #else 

    @available(*, unavailable, message: "Setting the statx attributes is not supported on Linux / Android, please use inode flags instead")
    static func setFileAttributes(forItemAt path: FilePath, attributes: CInterop.PlatformFileAttribute) throws(SystemError) {
        fatalError("Not Supported")
    }


    @available(*, unavailable, message: "Setting the statx attributes is not supported on Linux / Android, please use inode flags instead")
    static func setFileAttributes(for handle: borrowing UnsafeSystemHandle, attributes: CInterop.PlatformFileAttribute) throws(SystemError) {
        fatalError("Not Supported")
    }


    static func setFileInodeFlags(forItemAt path: FilePath, flags: CInterop.PosixInodeFlags) throws(SystemError) {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly(), noFollow: true))
        try setFileInodeFlags(for: fd, flags: flags)
        try fd.close()
    }


    static func setFileInodeFlags(for handle: borrowing UnsafeSystemHandle, flags: CInterop.PosixInodeFlags) throws(SystemError) {
        var flags = flags
        try execThrowingCFunction {
            return ioctl(handle.unsafeRawHandle, _FS_IOC_SETFLAGS, &flags)
        }
    }


    static func readFileInodeFlags(forItemAt path: FilePath) throws(SystemError) -> CInterop.PosixInodeFlags {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        let flags = try readFileInodeFlags(for: fd)
        try fd.close()
        return flags
    }


    static func readFileInodeFlags(for handle: borrowing UnsafeSystemHandle) throws(SystemError) -> CInterop.PosixInodeFlags {
        var flags: CInterop.PosixInodeFlags = 0
        try execThrowingCFunction {
            ioctl(handle.unsafeRawHandle, _FS_IOC_GETFLAGS, &flags)
        }
        return flags
    }

    #endif 

}



// MARK: - Permissions
extension InternalFS {

    #if canImport(WinSDK)

    // TODO: Switch to Windows DACL implementation
    static func setFilePermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(SystemError) {

        #warning("Not implemented")
        fatalError("Not implemented")

    }


    static func setFilePermissions(for handle: borrowing UnsafeSystemHandle, permissions: FilePermissions) throws(SystemError) {

        #warning("Not implemented")
        fatalError("Not implemented")

    }


    static func readFileSecurityDescriptor(forItemAt path: FilePath) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {
        #warning("Not implemented")
        fatalError("Not implemented")
    }


    static func readFileSecurityDescriptor(for handle: borrowing UnsafeSystemHandle) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {
        #warning("Not implemented")
        fatalError("Not implemented")
    }

    #else

    static func setFilePermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(SystemError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                fchmodat(AT_FDCWD, pathPtr, permissions.rawValue, AT_SYMLINK_NOFOLLOW)
            }
        }
    }


    static func setFilePermissions(for handle: borrowing UnsafeSystemHandle, permissions: FilePermissions) throws(SystemError) {
        try execThrowingCFunction {
            fchmod(handle.unsafeRawHandle, permissions.rawValue)
        }
    }

    #endif 

}
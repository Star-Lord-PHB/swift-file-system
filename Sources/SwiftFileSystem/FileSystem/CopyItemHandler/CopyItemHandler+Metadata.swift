import FileSystemCore
import struct SystemPackage.FilePath
import struct SystemPackage.FilePermissions



extension CopyItemHandler {

    struct CachedCopySrcItemAttrs: ~Copyable {

        // this type is used instead of ``InternalFS.InternalFileTimes`` since we don't need ctime
        struct CachedFileTimes {
            let accessTime: FileTimeSpec
            let modificationTime: FileTimeSpec
            let creationTime: FileTimeSpec?
        }

        let info: FileInfo

        var type: FileKind { info.type }

        var fileTimes: CachedFileTimes {
            .init(
                accessTime: info.times.lastAccess, 
                modificationTime: info.times.lastModification, 
                creationTime: info.times.creation
            )
        }

        var accessTime: FileTimeSpec { info.times.lastAccess }
        var modificationTime: FileTimeSpec { info.times.lastModification }
        var statusChangeTime: FileTimeSpec { info.times.lastChange }
        var creationTime: FileTimeSpec? { info.times.creation }

        #if canImport(Glibc) || canImport(Musl)
        // on Linux, inode flags are not available for symlinks
        let attributes: LinuxInodeFlags?
        #else
        // on other platforms, file flags should always be available
        var attributes: PlatformFileAttributes { info.attributes }
        #endif 

        #if canImport(WinSDK)
        let securityDescriptor: WindowsSelfRelativeSecurityDescriptor
        #else 
        let permission: FilePermissions
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    func cacheItemAttrsForCopy(forHandle handle: borrowing UnsafeSystemHandle) throws(LowLevelError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try handle.fileInfo()
        let sd = try handle.securityInfo(.dacl)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try handle.fstat()

        #if canImport(Glibc) || canImport(Musl)

        do {
            let flags = try handle.fileInodeFlags()
            return .init(info: .init(stat: stat), attributes: flags, permission: .init(rawValue: stat.st_mode & 0o7777))
        } catch let error where error.kind == .unsupported {
            return .init(info: .init(stat: stat), attributes: nil, permission: .init(rawValue: stat.st_mode & 0o7777))
        }

        #else

        return .init(info: .init(stat: stat), permission: .init(rawValue: stat.st_mode & 0o7777))

        #endif

        #endif 

    }


    func cacheItemAttrsForCopy(forItemAt path: FilePath) throws(LowLevelError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try InternalFS.getFileInfo(forItemAt: path, followSymlink: false)
        let sd = try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl, followSymlink: false)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try InternalFS.ulstat(path)

        #if canImport(Glibc) || canImport(Musl)

        do {
            let flags = if FileKind(mode: stat.st_mode) != .symlink {
                try InternalFS.readFileInodeFlags(forItemAt: path, followSymlink: false)
            } else {
                nil as LinuxInodeFlags?
            }
            return .init(info: .init(stat: stat), attributes: flags, permission: .init(rawValue: stat.st_mode & 0o7777))
        } catch let error where error.kind == .unsupported {
            return .init(info: .init(stat: stat), attributes: nil, permission: .init(rawValue: stat.st_mode & 0o7777))
        }

        #else

        return .init(info: .init(stat: stat), permission: .init(rawValue: stat.st_mode & 0o7777))

        #endif 

        #endif 

    }


    struct CachedCopySrcItemAttrMembers: OptionSet, Sendable {
        let rawValue: Int
        static var fileTimes: Self { CachedCopySrcItemAttrMembers(rawValue: 1 << 0) }
        static var permissions: Self { CachedCopySrcItemAttrMembers(rawValue: 1 << 1) }
        static var flags: Self { CachedCopySrcItemAttrMembers(rawValue: 1 << 2) }
        static var all: Self { [.fileTimes, .permissions, .flags] }
    }


    #if canImport(WinSDK)
    fileprivate func mapNonInheritAcesToExplicitAccess(_ aces: WindowsRawAcl.View?) -> WindowsExplicitAccessArray {

        var explicitAccess = WindowsExplicitAccessArray()

        aces?.forEach { ace in
            guard !ace.flags.contains(.inherited) else { return }
            let accessMode = switch ace.type {
                case .allow: .grantAccess
                case .deny: .denyAccess
                default: nil
            } as WindowsExplicitAccess.AccessMode?
            guard let accessMode else { return }
            var inheritance = [] as WindowsExplicitAccess.Inheritance
            if ace.flags.contains(.objectInherit) { inheritance.insert(.subFiles) }
            if ace.flags.contains(.containerInherit) { inheritance.insert(.subContainers) }
            if ace.flags.contains(.noPropagateInherit) { inheritance.insert(.noPropagate) }
            if ace.flags.contains(.inheritOnly) { inheritance.insert(.inheritOnly) }
            if inheritance.isEmpty { inheritance.insert(.noInheritance) }
            explicitAccess.append(.init(
                permission: ace.permission.mask, 
                accessMode: accessMode, 
                inheritance: inheritance, 
                trustee: .init(sid: ace.permission.sid.detach(), type: .unknown)
            ))
        }

        return explicitAccess

    }
    

    fileprivate func writeWindowsDacl(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        if cachedAttrs.securityDescriptor.control.control.contains(.daclProtected) {

            try execThrowingCFunction {
                SetKernelObjectSecurity(
                    handle.unsafeRawHandle, 
                    DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION), 
                    cachedAttrs.securityDescriptor.psd.unsafelyCastedMutableRawPtr
                )
            }

        } else if cachedAttrs.securityDescriptor.control.control.contains(.daclAutoInherited) {

            let explicitAccess = mapNonInheritAcesToExplicitAccess(cachedAttrs.securityDescriptor.dacl.value)

            if !explicitAccess.isEmpty {

                var sd = try handle.securityInfo(.dacl).makeAbsolute()
                sd.addDaclEntries(explicitAccess)

                try execThrowingCFunction {
                    SetKernelObjectSecurity(
                        handle.unsafeRawHandle, DWORD(DACL_SECURITY_INFORMATION), sd.psd.unsafeRawPtr
                    )
                }   

            }

        } else {
            // If both DACL_PROTECTED and DACL_AUTO_INHERITED are not set, we assume that this DACL is 
            // inherited from the parent directory and hasn't been modified. In this case, we don't copy
            // any security information and let the destination item inherit everyting from its parent directory.
        }

    }


    fileprivate func writeWindowsDacl(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        if cachedAttrs.securityDescriptor.control.control.contains(.daclProtected) {

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in
                    SetFileSecurityW(
                        pathPtr, 
                        DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION), 
                        cachedAttrs.securityDescriptor.psd.unsafelyCastedMutableRawPtr
                    )
                }
            }

        } else if cachedAttrs.securityDescriptor.control.control.contains(.daclAutoInherited) {

            let explicitAccess = mapNonInheritAcesToExplicitAccess(cachedAttrs.securityDescriptor.dacl.value)

            if !explicitAccess.isEmpty {

                var sd = try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl, followSymlink: false).makeAbsolute()
                sd.addDaclEntries(explicitAccess)

                try execThrowingCFunction {
                    path.withPlatformString { pathPtr in
                        SetFileSecurityW(pathPtr, DWORD(DACL_SECURITY_INFORMATION), sd.psd.unsafeRawPtr)
                    }
                }

            }

        } else {
            // If both DACL_PROTECTED and DACL_AUTO_INHERITED are not set, we assume that this DACL is 
            // inherited from the parent directory and hasn't been modified. In this case, we don't copy
            // any security information and let the destination item inherit everyting from its parent directory.
        }

    }


    fileprivate func writeWindowsDaclExact(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        let securityInformation = cachedAttrs.securityDescriptor.control.control.contains(.daclProtected) 
            ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
            : DWORD(DACL_SECURITY_INFORMATION)
        try execThrowingCFunction {
            SetKernelObjectSecurity(
                handle.unsafeRawHandle, 
                securityInformation, 
                cachedAttrs.securityDescriptor.psd.unsafelyCastedMutableRawPtr
            )
        }
    }


    fileprivate func writeWindowsDaclExact(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        let securityInformation = cachedAttrs.securityDescriptor.control.control.contains(.daclProtected) 
            ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
            : DWORD(DACL_SECURITY_INFORMATION)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                SetFileSecurityW(
                    pathPtr, 
                    securityInformation, 
                    cachedAttrs.securityDescriptor.psd.unsafelyCastedMutableRawPtr
                )
            }
        }
    }
    #endif


    func writeCachedFileTimes(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        try handle.setFileTimes(
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime, 
            creation: cachedAttrs.creationTime
        )
    }


    func writeCachedFileTimes(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        try InternalFS.setFileTimes(
            forItemAt: path, 
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime, 
            creation: cachedAttrs.creationTime, 
            followSymlink: false
        )
    }


    func writeCachedPermissions(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        #if canImport(WinSDK)
        if options.windowsPreserveExactDacl {
            try writeWindowsDaclExact(forHandle: handle, cachedAttrs: cachedAttrs)
        } else {
            try writeWindowsDacl(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        #else
        try handle.setPosixPermissions(cachedAttrs.permission)
        #endif
    }


    func writeCachedPermissions(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        #if canImport(WinSDK)
        if options.windowsPreserveExactDacl {
            try writeWindowsDaclExact(forItemAt: path, cachedAttrs: cachedAttrs)
        } else {
            try writeWindowsDacl(forItemAt: path, cachedAttrs: cachedAttrs)
        }
        #else
        try InternalFS.setPosixPermissions(forItemAt: path, permissions: cachedAttrs.permission, followSymlink: false)
        #endif
    }


    func writeCachedItemAttrs(
        forHandle handle: borrowing UnsafeSystemHandle, 
        members: CachedCopySrcItemAttrMembers,
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        if members.contains(.fileTimes) {
            try writeCachedFileTimes(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        #if canImport(WinSDK)
        if members.contains(.flags) {
            try writeCachedItemFlags(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        if members.contains(.permissions) {
            try writeCachedPermissions(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        #else
        if members.contains(.permissions) {
            try writeCachedPermissions(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        if members.contains(.flags) {
            try writeCachedItemFlags(forHandle: handle, cachedAttrs: cachedAttrs)
        }
        #endif
    }


    func writeCachedItemAttrs(
        forItemAt path: FilePath, 
        members: CachedCopySrcItemAttrMembers,
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        if members.contains(.fileTimes) {
            try writeCachedFileTimes(forItemAt: path, cachedAttrs: cachedAttrs)
        }
        if members.contains(.permissions) {
            try writeCachedPermissions(forItemAt: path, cachedAttrs: cachedAttrs)
        }
        if members.contains(.flags) {
            try writeCachedItemFlags(forItemAt: path, cachedAttrs: cachedAttrs)
        }
    }


    #if canImport(Darwin)
    func copyDarwinExtendedAttrs(
        fromHandle srcHandle: borrowing UnsafeSystemHandle,
        toHandle dstHandle: borrowing UnsafeSystemHandle
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_XATTR | COPYFILE_ACL))
        }
    }
    #endif


    func writeCachedItemFlags(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        #if canImport(Glibc) || canImport(Musl)
        do throws(LowLevelError) {
            if let flags = cachedAttrs.attributes {
                try handle.setFileInodeFlags(flags)
            }
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting inode flags
        }
        #else
        do throws(LowLevelError) {
            try handle.setFileAttributes(cachedAttrs.attributes)
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting file attributes
        }
        #endif
    }


    func writeCachedItemFlags(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        #if canImport(Glibc) || canImport(Musl)
        do throws(LowLevelError) {
            if let flags = cachedAttrs.attributes {
                try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags, followSymlink: false)
            }
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting inode flags
        }
        #else
        do throws(LowLevelError) {
            try InternalFS.setFileAttributes(forItemAt: path, attributes: cachedAttrs.attributes, followSymlink: false)
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting file attributes
        }
        #endif
    }


    func openMetadataHandle(forItemAt path: FilePath) throws(LowLevelError) -> UnsafeSystemHandle {
        #if canImport(WinSDK)
        return try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(
                access: .readWrite(metadataOnly: true), 
                noFollow: true, 
                platformOpenFlagsDiff: .inserted(.windows.backupSemantics)
            )
        )
        #else
        return try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(), noFollow: true)
        )
        #endif
    }

}

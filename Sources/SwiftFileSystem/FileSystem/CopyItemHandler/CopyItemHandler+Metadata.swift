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
        let securityDescriptor: WindowsSelfRelativeSecurityDescriptor?
        var sdControl: WindowsSecurityDescriptorControl? { 
            switch securityDescriptor {
                case .some(let sd): return sd.control.control
                case .none: return nil
            }
        }
        var daclView: WindowsRawAcl.View? { 
            switch securityDescriptor {
                case .some(let sd): return sd.dacl.value
                case .none: return nil
            }
        }
        var psd: UnsafeMutablePointer<SECURITY_DESCRIPTOR>? {
            switch securityDescriptor {
                case .some(let sd): return sd.psd.unsafelyCastedMutableRawPtr
                case .none: return nil
            }
        }
        #else
        let permission: FilePermissions
        #endif


        #if canImport(Glibc) || canImport(Musl)
        init(stat: PlatformInteropTypes.Stat, attributes: LinuxInodeFlags?) {
            self.info = .init(stat: stat)
            self.attributes = attributes
            self.permission = .init(rawValue: stat.st_mode & 0o7777)
        }
        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        init(stat: PlatformInteropTypes.Stat) {
            self.info = .init(stat: stat)
            self.permission = .init(rawValue: stat.st_mode & 0o7777)
        }
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    mutating func cacheItemAttrsForCopy(
        forHandle handle: borrowing UnsafeSystemHandle
    ) throws(RecursiveCopyAbortError) -> CachedCopySrcItemAttrs? {

        #if canImport(WinSDK)

        let info = try errorCollector.execute(operation: .getSrcMetadata) {
            try handle.fileInfo()
        }
        guard let info else { return nil }
        let sd = try errorCollector.execute(operation: .copyPermissions) {
            try handle.securityInfo(.dacl)
        }

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try errorCollector.execute(operation: .getSrcMetadata) {
            try handle.fstat()
        }
        guard let stat else { return nil }

        #if canImport(Glibc) || canImport(Musl)

        do {
            let flags = try handle.fileInodeFlags()
            return .init(stat: stat, attributes: flags)
        } catch let error where error.kind == .unsupported {
            return .init(stat: stat, attributes: nil)
        } catch {
            try errorCollector.handleError(error, operation: .copyFlags)
            return .init(stat: stat, attributes: nil)
        }

        #else

        return .init(stat: stat)

        #endif

        #endif 

    }


    mutating func cacheItemAttrsForCopy(forItemAt itemRelativePath: FilePath) throws(RecursiveCopyAbortError) -> CachedCopySrcItemAttrs? {

        let path = srcAbsolutePath(of: itemRelativePath)

        #if canImport(WinSDK)

        let info = try errorCollector.execute(operation: .getSrcMetadata) {
            try InternalFS.getFileInfo(forItemAt: path, followSymlink: false)
        }
        guard let info else { return nil }
        let sd = try errorCollector.execute(operation: .copyPermissions) {
            try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl, followSymlink: false)
        }

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try errorCollector.execute(operation: .getSrcMetadata) {
            try InternalFS.ulstat(path)
        }
        guard let stat else { return nil }

        #if canImport(Glibc) || canImport(Musl)

        do {
            // Reading inode flags requires opening the item. Only regular files and directories
            // qualify: symlinks have no flags, and special files (a fifo would block the open)
            // are reported as unsupported before their flags could matter.
            let kind = FileKind(mode: stat.st_mode)
            let flags = if kind == .regular || kind == .directory {
                try InternalFS.readFileInodeFlags(forItemAt: path, followSymlink: false)
            } else {
                nil as LinuxInodeFlags?
            }
            return .init(stat: stat, attributes: flags)
        } catch let error where error.kind == .unsupported {
            return .init(stat: stat, attributes: nil)
        } catch {
            try errorCollector.handleError(error, operation: .copyFlags)
            return .init(stat: stat, attributes: nil)
        }

        #else

        return .init(stat: stat)

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
    

    /// Stamps `SE_DACL_AUTO_INHERIT_REQ` into the cached source security descriptor right
    /// before it is written verbatim, when the source is auto-inherited: the
    /// non-propagating write APIs only set the destination's `SE_DACL_AUTO_INHERITED`
    /// bookkeeping bit when this request bit accompanies the write. Deliberately applied
    /// only at the write sites so the cached control stays pristine for every decision
    /// made earlier in the copy.
    fileprivate func requestDaclAutoInheritedForVerbatimWrite(
        _ cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) {
        guard 
            cachedAttrs.sdControl?.contains(.daclAutoInherited) == true,
            let psd = cachedAttrs.psd
        else { return }
        let requestBit = SECURITY_DESCRIPTOR_CONTROL(SE_DACL_AUTO_INHERIT_REQ)
        SetSecurityDescriptorControl(psd, requestBit, requestBit)
    }


    fileprivate func writeWindowsDacl(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        guard cachedAttrs.securityDescriptor != nil else { return }

        if cachedAttrs.sdControl?.contains(.daclProtected) == true {

            requestDaclAutoInheritedForVerbatimWrite(cachedAttrs)
            try execThrowingCFunction {
                SetKernelObjectSecurity(
                    handle.unsafeRawHandle, 
                    DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION), 
                    cachedAttrs.psd
                )
            }

        } else {

            // Regardless of SE_DACL_AUTO_INHERITED: the kernel marks every ACE that came
            // from creation-time inheritance with INHERITED_ACE, so an unmarked ACE is an
            // entry somebody deliberately set on the item (a legacy-mode DACL written
            // wholesale is a self-contained policy consisting entirely of such entries).
            // Merge them into the DACL the destination inherited naturally; the marked
            // entries are the source parent's context and stay behind.
            let explicitAccess = mapNonInheritAcesToExplicitAccess(cachedAttrs.daclView)

            if !explicitAccess.isEmpty {

                var sd = try handle.securityInfo(.dacl).makeAbsolute()
                sd.dacl.addEntries(explicitAccess)

                // Stamp the result as auto-inherited (the write honors the bookkeeping
                // bit only together with the request bit): the merged DACL is in
                // canonical auto-inherited form, same as an ACL editor would leave it.
                sd.control.insert([.daclAutoInheritReq, .daclAutoInherited])

                try execThrowingCFunction {
                    SetKernelObjectSecurity(
                        handle.unsafeRawHandle, DWORD(DACL_SECURITY_INFORMATION), sd.psd.unsafeRawPtr
                    )
                }   

            }

        }

    }


    fileprivate func writeWindowsDacl(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        guard cachedAttrs.securityDescriptor != nil else { return }

        if cachedAttrs.sdControl?.contains(.daclProtected) == true {

            requestDaclAutoInheritedForVerbatimWrite(cachedAttrs)
            try execThrowingCFunction {
                path.withPlatformString { pathPtr in
                    SetFileSecurityW(
                        pathPtr, 
                        DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION), 
                        cachedAttrs.psd
                    )
                }
            }

        } else {

            // See the handle-based variant above: unmarked ACEs are deliberately set
            // entries regardless of SE_DACL_AUTO_INHERITED, and travel with the item.
            let explicitAccess = mapNonInheritAcesToExplicitAccess(cachedAttrs.daclView)

            if !explicitAccess.isEmpty {

                var sd = try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl, followSymlink: false).makeAbsolute()
                sd.dacl.addEntries(explicitAccess)

                sd.control.insert([.daclAutoInheritReq, .daclAutoInherited])

                try execThrowingCFunction {
                    path.withPlatformString { pathPtr in
                        SetFileSecurityW(pathPtr, DWORD(DACL_SECURITY_INFORMATION), sd.psd.unsafeRawPtr)
                    }
                }

            }

        }

    }


    fileprivate func writeWindowsDaclExact(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        guard cachedAttrs.securityDescriptor != nil else { return }
        let securityInformation = cachedAttrs.sdControl?.contains(.daclProtected) == true
            ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
            : DWORD(DACL_SECURITY_INFORMATION)
        requestDaclAutoInheritedForVerbatimWrite(cachedAttrs)
        try execThrowingCFunction {
            SetKernelObjectSecurity(handle.unsafeRawHandle, securityInformation, cachedAttrs.psd)
        }
    }


    fileprivate func writeWindowsDaclExact(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        guard cachedAttrs.securityDescriptor != nil else { return }
        let securityInformation = cachedAttrs.sdControl?.contains(.daclProtected) == true
            ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
            : DWORD(DACL_SECURITY_INFORMATION)
        requestDaclAutoInheritedForVerbatimWrite(cachedAttrs)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                SetFileSecurityW(pathPtr, securityInformation, cachedAttrs.psd)
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


    mutating func writeCachedItemAttrs(
        forHandle handle: borrowing UnsafeSystemHandle, 
        members: CachedCopySrcItemAttrMembers,
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {
        if members.contains(.fileTimes) {
            do {
                try writeCachedFileTimes(forHandle: handle, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyTimes) }
        }
        #if canImport(WinSDK)
        if members.contains(.flags) {
            do {
                try writeCachedItemFlags(forHandle: handle, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyFlags) }
        }
        if members.contains(.permissions) {
            do {
                try writeCachedPermissions(forHandle: handle, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyPermissions) }
        }
        #else
        if members.contains(.permissions) {
            do {
                try writeCachedPermissions(forHandle: handle, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyPermissions) }
        }
        if members.contains(.flags) {
            do {
                try writeCachedItemFlags(forHandle: handle, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyFlags) }
        }
        #endif
    }


    mutating func writeCachedItemAttrs(
        forItemAt path: FilePath, 
        members: CachedCopySrcItemAttrMembers,
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {
        if members.contains(.fileTimes) {
            do {
                try writeCachedFileTimes(forItemAt: path, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyTimes) }
        }
        #if canImport(WinSDK)
        if members.contains(.flags) {
            do {
                try writeCachedItemFlags(forItemAt: path, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyFlags) }
        }
        if members.contains(.permissions) {
            do {
                try writeCachedPermissions(forItemAt: path, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyPermissions) }
        }
        #else 
        if members.contains(.permissions) {
            do {
                try writeCachedPermissions(forItemAt: path, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyPermissions) }
        }
        if members.contains(.flags) {
            do {
                try writeCachedItemFlags(forItemAt: path, cachedAttrs: cachedAttrs)
            } catch { try errorCollector.handleError(error, operation: .copyFlags) }
        }
        #endif
    }


    #if canImport(Darwin)
    static func copyDarwinExtendedAttrs(
        fromHandle srcHandle: borrowing UnsafeSystemHandle,
        toHandle dstHandle: borrowing UnsafeSystemHandle
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_XATTR))
        }
    }

    static func copyDarwinACL(
        fromHandle srcHandle: borrowing UnsafeSystemHandle,
        toHandle dstHandle: borrowing UnsafeSystemHandle
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_ACL))
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

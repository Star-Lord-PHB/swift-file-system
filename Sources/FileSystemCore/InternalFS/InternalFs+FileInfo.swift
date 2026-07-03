import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    package static func getFileInfo(forItemAt path: FilePath, followSymlink: Bool = false) throws(SystemError) -> FileInfo {

        #if canImport(WinSDK)

        if let GetFileInformationByNameFuncPtr = getGetFileInformationByNameFuncPtr() {

            // A faster path for getting information of files without opening a handle

            var infoByName = FILE_STAT_BASIC_INFORMATION()

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in 
                    GetFileInformationByNameFuncPtr(pathPtr, FileStatBasicByNameInfo, &infoByName, DWORD(MemoryLayout<FILE_STAT_BASIC_INFORMATION>.size)).boolValue
                }
            }

            if !followSymlink || infoByName.ReparseTag != IO_REPARSE_TAG_SYMLINK {

                let type = if infoByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                    .symlink
                } else if (infoByName.FileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    .directory
                } else {
                    .regular
                } as FileType

                return .init(
                    size: .init(infoByName.EndOfFile.QuadPart), 
                    type: type,
                    times: .init(
                        lastAccess: .init(platformFileTime: infoByName.LastAccessTime), 
                        lastModification: .init(platformFileTime: infoByName.LastWriteTime), 
                        lastChange: .init(platformFileTime: infoByName.ChangeTime), 
                        creation: .init(platformFileTime: infoByName.CreationTime)
                    ), 
                    fileIdentifier: .init(fileId: infoByName.FileId128.uint128, deviceId: .init(infoByName.VolumeSerialNumber.QuadPart)), 
                    attributes: .init(rawValue: infoByName.FileAttributes), 
                    supportedAttributes: .all
                )

            }

            // if following symlink is required and the item is a symlink, fall back to use handle-based method

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: !followSymlink, platformSpecificOptions: .windows.backupSemantics)
        )

        return try handle.fileInfo()

        #else 

        let st = if followSymlink {
            try ustat(path)
        } else {
            try ulstat(path)
        }

        return .init(stat: st)

        #endif 

    }

}



// - MARK: File Type
extension InternalFS {

    package static func type(ofItemAt path: FilePath) throws(SystemError) -> FileType {
        
        #if canImport(WinSDK)

        if let GetFileInformationByNameFuncPtr = getGetFileInformationByNameFuncPtr() {

            // A faster path for getting information of files without opening a handle

            var infoByName = FILE_STAT_BASIC_INFORMATION()

            do {
                try execThrowingCFunction {
                    path.withPlatformString { pathPtr in 
                        GetFileInformationByNameFuncPtr(pathPtr, FileStatBasicByNameInfo, &infoByName, DWORD(MemoryLayout<FILE_STAT_BASIC_INFORMATION>.size)).boolValue
                    }
                }

                return if infoByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                    .symlink
                } else if (infoByName.FileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    .directory
                } else {
                    .regular
                }
            } catch let e where e.kind == .notFound || e.kind == .nameTooLong || e.code == .system(.invalidFileName) {
                // These errors are won't be resolved even after falling back to handle-based method
                // MARK: TODO: Need to check whether there are other error codes like these
                throw e
            } catch {
                // Fallback to handle-based method
            }

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: true, platformSpecificOptions: .windows.backupSemantics)
        )

        return try handle.type()

        #else 

        return .init(mode: try ulstat(path).st_mode)

        #endif

    }

}



// MARK: - Times
extension InternalFS {

    package static func setFileTimes(
        forItemAt path: FilePath, 
        access: FileTimeSpec?, 
        modification: FileTimeSpec?,
        creation: FileTimeSpec? = nil
    ) throws(SystemError) {

        if access == nil && modification == nil && creation == nil { return }

        #if canImport(WinSDK)

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .writeOnly(metadataOnly: true), noFollow: true, platformSpecificOptions: .windows.backupSemantics)
        )
        try handle.setFileTimes(access: access, modification: modification, creation: creation)
        try handle.close()

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        // MARK: TODO: on Darwin, use setattrlist to set the three times in one syscall

        let access = access ?? .utimeOmit

        var times = (access, FileTimeSpec(platformFileTime: .init()))

        if let creation {
            times.1 = creation
            try self.utimens(for: path, times: times)
        }

        guard creation == nil || modification != nil else {
            // the next call is only necessary when creation time is not set or modification time need to be set
            return
        }

        times.1 = modification ?? .utimeOmit

        try self.utimens(for: path, times: times)

        #else 

        var times = (access ?? .utimeOmit, modification ?? .utimeOmit)

        try self.utimens(for: path, times: times)

        #endif 

    }


    package static func getFileTimes(
        fromItemAt path: FilePath
    ) throws(SystemError) -> FileTimes {

        #if canImport(WinSDK)

        if let getFileInformationByNamePtr = getGetFileInformationByNameFuncPtr() {

            var fileInfo =  FILE_STAT_INFORMATION()

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in 
                    getFileInformationByNamePtr(pathPtr, FileStatByNameInfo, &fileInfo, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size)).boolValue
                }
            }

            return .init(
                lastAccess: .init(largeInteger: fileInfo.LastAccessTime), 
                lastModification: .init(largeInteger: fileInfo.LastWriteTime), 
                lastChange: .init(largeInteger: fileInfo.ChangeTime),
                creation: .init(largeInteger: fileInfo.CreationTime)
            )

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: true)
        )
        
        let times = try handle.fileTimes()

        try handle.close()

        return times

        #else

        let st = try ulstat(path)
        return .init(
            lastAccess: st.st_atim, 
            lastModification: st.st_mtim, 
            lastChange: st.st_ctim,
            creation: st.st_btim
        )

        #endif 

    }

}



// MARK: - Attributes & Flags
extension InternalFS {

    package static func getFileAttributes(forItemAt path: FilePath) throws(SystemError) -> PlatformFileAttributes {
        #if canImport(WinSDK)
        let attribubtes = path.withPlatformString { pathPtr in 
            GetFileAttributesW(pathPtr)
        }
        guard attribubtes != DWORD(INVALID_FILE_ATTRIBUTES) else {
            try SystemError.assertError()
        }
        return .init(rawValue: attribubtes)
        #else 
        .init(rawValue: try ustat(path).st_flags)
        #endif
    }

    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    package static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                SetFileAttributesW(pathPtr, attributes.rawValue)
            }
        }

        #else

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                lchflags(pathPtr, attributes.rawValue)
            }
        }

        #endif 

    }

    #else 

    @available(*, unavailable, message: "Setting the statx attributes is not supported on Linux / Android, please use inode flags instead")
    package static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(SystemError) {
        throw SystemError(code: .notSupported)!
    }


    package static func setFileInodeFlags(forItemAt path: FilePath, flags: CInterop.PosixInodeFlags) throws(SystemError) {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        try fd.setFileInodeFlags(flags)
        try fd.close()
    }


    package static func readFileInodeFlags(forItemAt path: FilePath) throws(SystemError) -> CInterop.PosixInodeFlags {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        let flags = try fd.fileInodeFlags()
        try fd.close()
        return flags
    }


    package static func fileAttributesToInodeFlags(_ attributes: PlatformFileAttributes) -> CInterop.PosixInodeFlags {
        var inodeFlags = 0 as CInterop.PosixInodeFlags
        if attributes.isCompressed { inodeFlags |= FS_COMPR_FL }
        if attributes.isImmutable { inodeFlags |= FS_IMMUTABLE_FL }
        if attributes.isAppendOnly { inodeFlags |= FS_APPEND_FL }
        if attributes.noDump { inodeFlags |= FS_NODUMP_FL }
        if attributes.isEncrypted { inodeFlags |= FS_ENCRYPT_FL }
        if attributes.isVerityProtected { inodeFlags |= FS_VERITY_FL }
        return inodeFlags
    }

    #endif 

}



// MARK: - Permissions
extension InternalFS {
    
    package static func canAccess(
        itemAt path: FilePath,
        for accessMode: FileOperationOptions.FileAccessMode = [.read, .write],
        followSymlink: Bool = true
    ) throws(SystemError) -> Bool {
        
        #if canImport(WinSDK)

        var processToken = nil as HANDLE?
        try execThrowingCFunction {
            OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY | TOKEN_DUPLICATE), &processToken)
        }
        defer { CloseHandle(processToken) }

        var impersonationToken = nil as HANDLE?
        try execThrowingCFunction {
            DuplicateToken(processToken, SecurityImpersonation, &impersonationToken)
        }
        defer { CloseHandle(impersonationToken) }
        
        let sd = try getSecurityInfo(forItemAt: path, members: .all)

        var fileGenericMapping = GENERIC_MAPPING(
            GenericRead: FILE_GENERIC_READ, 
            GenericWrite: FILE_GENERIC_WRITE, 
            GenericExecute: FILE_GENERIC_EXECUTE, 
            GenericAll: FILE_ALL_ACCESS
        )

        var desiredAccess = 0 as DWORD
        if accessMode.contains(.read) { desiredAccess |= DWORD(GENERIC_READ) }
        if accessMode.contains(.write) { desiredAccess |= DWORD(GENERIC_WRITE) }
        if accessMode.contains(.execute) { desiredAccess |= DWORD(GENERIC_EXECUTE) }

        var mappedDesiredAccess = desiredAccess;
        MapGenericMask(&mappedDesiredAccess, &fileGenericMapping);

        var privilegeSet = PRIVILEGE_SET()
        var privilegeSetLength = DWORD(MemoryLayout<PRIVILEGE_SET>.size)
        var grantedAccess = 0 as DWORD
        var accessStatus = false as WindowsBool
        
        try execThrowingCFunction {
            AccessCheck(
                sd.psd.unsafelyCastedMutableRawPtr, impersonationToken, mappedDesiredAccess, 
                &fileGenericMapping, &privilegeSet, &privilegeSetLength, &grantedAccess, &accessStatus
            )
        }

        return accessStatus.boolValue
        
        #else
        
        var mode = 0 as Int32
        if accessMode.contains(.read) { mode |= R_OK }
        if accessMode.contains(.write) { mode |= W_OK }
        if accessMode.contains(.execute) { mode |= X_OK }
        
        let response = path.withPlatformStringTypedThrow { pathPtr in
            PlatformCLib.faccessat(AT_FDCWD, pathPtr, mode, followSymlink ? 0 : AT_SYMLINK_NOFOLLOW)
        }
        
        if response == 0 { return true }
        
        guard let error = SystemError.fromLastError() else {
            fatalError("Expect to catch an error when faccessat returns -1, but none was thrown")
        }
        
        switch error.code {
            case .system(.permissionDenied),
                 .system(.operationNotPermitted),
                 .system(.readOnlyFileSystem): return false
            default: throw error
        }
        
        #endif
        
    }
    

    #if canImport(WinSDK)

    package static func setFileSecurityInfo(
        forItemAt path: FilePath, 
        setting members: FileOperationOptions.WindowsSecurityInfoMembers,
        dacl: consuming WindowsRawAcl?, 
        sacl: consuming WindowsRawAcl?, 
        owner: WindowsSid?, 
        group: WindowsSid?
    ) throws(SystemError) {

        guard !members.isEmpty else { return }

        try execThrowingCFunction { 
            path.withPlatformString { pathPtr in 
                SetNamedSecurityInfoW(
                    .init(mutating: pathPtr), SE_FILE_OBJECT, members.rawValue, 
                    owner?.psid.unsafeResourcePtr, group?.psid.unsafeResourcePtr, 
                    dacl?.pacl.unsafelyCastedMutableRawPtr, sacl?.pacl.unsafelyCastedMutableRawPtr
                )
            }
        } onError: { (code) throws(SystemError) in
            if let error = SystemError(code: code) {
                throw error
            }
        }

    }


    package static func getSecurityInfo(forItemAt path: FilePath, members: FileOperationOptions.WindowsSecurityInfoMembers) throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {
        
        var psd = nil as PSECURITY_DESCRIPTOR?

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                GetNamedSecurityInfoW(
                    pathPtr, SE_FILE_OBJECT, members.rawValue,
                    nil, nil, nil, nil, &psd
                )
            }
        } onError: { (code) throws(SystemError) in
            if let error = SystemError(code: code) {
                throw error
            }
        }

        precondition(psd != nil, "Read security descriptor success but returned null pointer")

        return .init(psd: .init(owningPointer: psd!.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), allocator: .localAlloc))

    }

    #else
    
    package static func getPosixPermissions(
        forItemAt path: FilePath,
        followSymlink: Bool = true
    ) throws(SystemError) -> FilePermissions {
        if followSymlink {
            return try .init(rawValue: ustat(path).st_mode)
        } else {
            return try .init(rawValue: ulstat(path).st_mode)
        }
    }
    

    package static func setPosixPermissions(
        forItemAt path: FilePath,
        permissions: FilePermissions,
        followSymlink: Bool = true
    ) throws(SystemError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                fchmodat(AT_FDCWD, pathPtr, permissions.rawValue, followSymlink ? 0 : AT_SYMLINK_NOFOLLOW)
            }
        }
    }

    #endif
    
    
    package static func getOwner(
        forItemAt path: FilePath,
        followSymlink: Bool = true
    ) throws(SystemError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        
        #if canImport(WinSDK)
        
        let sd = try getSecurityInfo(forItemAt: path, members: [.owner, .group])

        guard let owner = sd.owner?.sid.detach() else {
            fatalError("Fail to get the owner SID from SECURITY_DESCRIPTOR")
        }
        guard let group = sd.group?.sid.detach() else {
            fatalError("Fail to get the group SID from SECURITY_DESCRIPTOR")
        }
        
        return (
            owner: .init(rawId: owner, platformKind: .user),
            group: .init(rawId: group, platformKind: .group)
        )
        
        #else
        
        let st = try followSymlink ? ustat(path) : ulstat(path)
        
        return (
            owner: .init(rawId: st.st_uid, platformKind: .user),
            group: .init(rawId: st.st_gid, platformKind: .group)
        )
        
        #endif
        
    }
    
    
    package static func chown(
        forItemAt path: FilePath,
        owner: PlatformIdentity?,
        group: PlatformIdentity?,
        followSymlink: Bool = true
    ) throws(SystemError) {
        
        #if canImport(WinSDK)
        
        var settingMembers = [] as FileOperationOptions.WindowsSecurityInfoMembers
        if owner != nil {
            settingMembers.insert(.owner)
        }
        if group != nil {
            settingMembers.insert(.group)
        }
        guard !settingMembers.isEmpty else { return }
        try setFileSecurityInfo(forItemAt: path, setting: settingMembers, dacl: nil, sacl: nil, owner: owner?.rawId, group: group?.rawId)
        
        #else
        
        if owner == nil && group == nil { return }
        precondition(owner?.platformKind != .group, "owner identity must be of user kind")
        precondition(group?.platformKind != .user, "group identity must be of group kind")
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                PlatformCLib.fchownat(
                    AT_FDCWD, pathPtr,
                    owner?.rawId ?? .init(bitPattern: -1), group?.rawId ?? .init(bitPattern: -1),
                    followSymlink ? 0 : AT_SYMLINK_NOFOLLOW
                )
            }
        }
        
        #endif
        
    }

}

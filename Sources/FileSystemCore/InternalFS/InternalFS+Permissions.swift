import PlatformCLib
import CFileSystem
import SystemPackage


extension InternalFS {
    
    package static func canAccess(
        itemAt path: FilePath,
        for accessMode: FileOperationOptions.FileAccessMode = [.read, .write],
        followSymlink: Bool
    ) throws(LowLevelError) -> Bool {
        
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
        
        let sd = try getSecurityInfo(forItemAt: path, members: .allExceptSacl, followSymlink: followSymlink)

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
        
        guard let error = LowLevelError.fromLastError() else {
            fatalError("Expect to catch an error when faccessat returns -1, but none was thrown")
        }
        
        switch error.systemCode {
            case .permissionDenied,
                 .operationNotPermitted,
                 .readOnlyFileSystem: return false
            default: throw error
        }
        
        #endif
        
    }
    

    #if canImport(WinSDK)

    package static func setSecurityInfo(
        forItemAt path: FilePath, 
        setting members: FileOperationOptions.WindowsSecurityInfoMembers,
        dacl: WindowsRawAcl.View?, 
        sacl: WindowsRawAcl.View?, 
        owner: WindowsSid?, 
        group: WindowsSid?,
        followSymlink: Bool
    ) throws(LowLevelError) {

        guard !members.isEmpty else { return }
        
        if followSymlink {
            let handle = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .writeOnly(metadataOnly: true), noFollow: !followSymlink, platformOpenFlagsDiff: .inserted(.windows.backupSemantics))
            )
            try handle.setSecurityInfo(members, dacl: dacl, sacl: sacl, owner: owner, group: group)
            try handle.close()
            return
        }

        try execThrowingCFunction { 
            path.withPlatformString { pathPtr in 
                SetNamedSecurityInfoW(
                    .init(mutating: pathPtr), SE_FILE_OBJECT, members.rawValue, 
                    owner?.psid.unsafeResourcePtr, group?.psid.unsafeResourcePtr, 
                    dacl?.pacl.unsafelyCastedMutableRawPtr, sacl?.pacl.unsafelyCastedMutableRawPtr
                )
            }
        } onError: { (code) throws(LowLevelError) in
            if let error = LowLevelError(rawSystemCode: code) {
                throw error
            }
        }

    }


    package static func getSecurityInfo(
        forItemAt path: FilePath,
        members: FileOperationOptions.WindowsSecurityInfoMembers,
        followSymlink: Bool
    ) throws(LowLevelError) -> WindowsSelfRelativeSecurityDescriptor {
        
        var psd = nil as PSECURITY_DESCRIPTOR?
        
        if followSymlink {
            let handle = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: !followSymlink, platformOpenFlagsDiff: .inserted(.windows.backupSemantics))
            )
            let sd = try handle.securityInfo(members)
            try handle.close()
            return sd
        }

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                GetNamedSecurityInfoW(
                    pathPtr, SE_FILE_OBJECT, members.rawValue,
                    nil, nil, nil, nil, &psd
                )
            }
        } onError: { (code) throws(LowLevelError) in
            if let error = LowLevelError(rawSystemCode: code) {
                throw error
            }
        }

        precondition(psd != nil, "Read security descriptor success but returned null pointer")

        return .init(psd: .init(owningPointer: psd!.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), allocator: .localAlloc))

    }

    #else
    
    package static func getPosixPermissions(
        forItemAt path: FilePath,
        followSymlink: Bool
    ) throws(LowLevelError) -> FilePermissions {
        let mode = try followSymlink ? ustat(path).st_mode : ulstat(path).st_mode
        return .init(rawValue: mode & 0o7777)
    }
    

    package static func setPosixPermissions(
        forItemAt path: FilePath,
        permissions: FilePermissions,
        followSymlink: Bool
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                fchmodat(AT_FDCWD, pathPtr, permissions.rawValue, followSymlink ? 0 : AT_SYMLINK_NOFOLLOW)
            }
        }
    }

    #endif
    
    
    package static func getOwner(
        forItemAt path: FilePath,
        followSymlink: Bool
    ) throws(LowLevelError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        
        #if canImport(WinSDK)
        
        let sd = try getSecurityInfo(forItemAt: path, members: [.owner, .group], followSymlink: followSymlink)

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
        followSymlink: Bool
    ) throws(LowLevelError) {
        
        #if canImport(WinSDK)
        
        var settingMembers = [] as FileOperationOptions.WindowsSecurityInfoMembers
        if owner != nil {
            settingMembers.insert(.owner)
        }
        if group != nil {
            settingMembers.insert(.group)
        }
        guard !settingMembers.isEmpty else { return }
        try setSecurityInfo(
            forItemAt: path, setting: settingMembers,
            dacl: nil, sacl: nil,
            owner: owner?.rawId, group: group?.rawId,
            followSymlink: followSymlink
        )
        
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

import SystemPackage
import PlatformCLib



extension UnsafeSystemHandle {

    package func fileInfo() throws(LowLevelError) -> FileInfo {

        #if canImport(WinSDK)

        var fileStandardInfo = FILE_STANDARD_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(unsafeRawHandle, FileStandardInfo, &fileStandardInfo, DWORD(MemoryLayout<FILE_STANDARD_INFO>.size))
        }

        var fileBasicInfo = FILE_BASIC_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        let type = try type(prefetchedAttributes: fileBasicInfo.FileAttributes)

        var fileIdInfo = FILE_ID_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                unsafeRawHandle, FileIdInfo, &fileIdInfo, DWORD(MemoryLayout<FILE_ID_INFO>.size)
            )
        }

        return .init(
            size: .init(fileStandardInfo.EndOfFile.QuadPart), 
            type: type, 
            times: .init(
                lastAccess: .init(largeInteger: fileBasicInfo.LastAccessTime), 
                lastModification: .init(largeInteger: fileBasicInfo.LastWriteTime), 
                lastChange: .init(largeInteger: fileBasicInfo.ChangeTime), 
                creation: .init(largeInteger: fileBasicInfo.CreationTime)
            ),
            fileIdentifier: .init(fileId: fileIdInfo.FileId.uint128, deviceId: fileIdInfo.VolumeSerialNumber), 
            attributes: .init(rawValue: fileBasicInfo.FileAttributes), 
            supportedAttributes: .all
        )

        #else 

        return .init(stat: try self.fstat())

        #endif

    }

}



extension UnsafeSystemHandle {

    package func type() throws(LowLevelError) -> FileKind {

        #if canImport(WinSDK)

        var fileBasicInfo = FILE_BASIC_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        return try type(prefetchedAttributes: fileBasicInfo.FileAttributes)

        #else

        return .init(mode: try self.fstat().st_mode)

        #endif

    }


    #if canImport(WinSDK)
    fileprivate func type(prefetchedAttributes: DWORD) throws(LowLevelError) -> FileKind {

        SetLastError(DWORD(NO_ERROR))
        let fileTypeFlags = GetFileType(unsafeRawHandle)
        try LowLevelError.check()

        var reparseTag: DWORD {
            get throws(LowLevelError) {
                guard prefetchedAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 else {
                    return 0
                }
                var fileAttributeTagInfo = _FILE_ATTRIBUTE_TAG_INFO()
                let structSize = DWORD(MemoryLayout<_FILE_ATTRIBUTE_TAG_INFO>.size)
                try execThrowingCFunction {
                    GetFileInformationByHandleEx(unsafeRawHandle, FileAttributeTagInfo, &fileAttributeTagInfo, structSize)
                }
                return fileAttributeTagInfo.ReparseTag
            }
        }

        return switch fileTypeFlags {
            case .init(FILE_TYPE_DISK):
                FileKind(windowsFileAttributes: prefetchedAttributes, reparseTag: try reparseTag)
            case .init(FILE_TYPE_CHAR):                         .character
            case .init(FILE_TYPE_PIPE):                         .fifo
            default:                                            .unknown
        }

    }
    #endif 

}



extension UnsafeSystemHandle {

    package func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(LowLevelError) {

        if access == nil && modification == nil && creation == nil { return }

        #if canImport(WinSDK)

        let platformAccess = access?.platformFileTime
        let platformModify = modification?.platformFileTime
        let platformCreation = creation?.platformFileTime

        try execThrowingCFunction {
            withUnsafeOptionalPointer(to: platformCreation) { creationPtr in 
                withUnsafeOptionalPointer(to: platformAccess) { accessPtr in 
                    withUnsafeOptionalPointer(to: platformModify) { modifyPtr in 
                        PlatformCLib.SetFileTime(
                            unsafeRawHandle, 
                            creationPtr, 
                            accessPtr, 
                            modifyPtr
                        )
                    }
                }
            }
        }

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        let access = access ?? .utimeOmit
        var times = (access, FileTimeSpec(platformFileTime: .init()))

        if let creation {
            times.1 = creation
            try futimens(times)
        }

        times.1 = modification ?? .utimeOmit

        try futimens(times)

        #else 

        var times = (access ?? .utimeOmit, modification ?? .utimeOmit)

        try futimens(times)

        #endif 

    }


    package func fileTimes() throws(LowLevelError) -> FileTimes {

        #if canImport(WinSDK)

        var fileBasicInfo = FILE_BASIC_INFO()

        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        return .init(
            lastAccess: .init(largeInteger: fileBasicInfo.LastAccessTime), 
            lastModification: .init(largeInteger: fileBasicInfo.LastWriteTime), 
            lastChange: .init(largeInteger: fileBasicInfo.ChangeTime),
            creation: .init(largeInteger: fileBasicInfo.CreationTime)
        )

        #else

        let st = try fstat()
        return .init(
            lastAccess: st.st_atim, 
            lastModification: st.st_mtim, 
            lastChange: st.st_ctim,
            creation: st.st_btim
        )

        #endif 

    }

}



extension UnsafeSystemHandle {

    package func fileAttributes() throws(LowLevelError) -> PlatformFileAttributes {
        #if canImport(WinSDK)
        var fileBasicInfo = FILE_BASIC_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }
        return .init(rawValue: fileBasicInfo.FileAttributes)
        #else 
        .init(rawValue: try fstat().st_flags)
        #endif
    }


    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    package func setFileAttributes(_ attributes: PlatformFileAttributes) throws(LowLevelError) {

        #if canImport(WinSDK)

        var basicInfo = FILE_BASIC_INFO(
            CreationTime: .init(QuadPart: -1), 
            LastAccessTime: .init(QuadPart: -1), 
            LastWriteTime: .init(QuadPart: -1), 
            ChangeTime: .init(QuadPart: -1), 
            FileAttributes: attributes.normalized.rawValue
        )

        try execThrowingCFunction {
            SetFileInformationByHandle(
                unsafeRawHandle, FileBasicInfo, &basicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        #else

        try execThrowingCFunction {
            fchflags(unsafeRawHandle, attributes.rawValue)
        }

        #endif 

    }

    #else 

    @available(*, unavailable, message: "Setting the statx attributes is not supported on Linux / Android, please use inode flags instead")
    package func setFileAttributes(_ attributes: PlatformFileAttributes) throws(LowLevelError) {
        throw .init(kind: .unsupported)
    }


    package func fileInodeFlags() throws(LowLevelError) -> LinuxInodeFlags {
        var flags: PlatformInteropTypes.PosixInodeFlags = 0
        try execThrowingCFunction {
            ioctl(unsafeRawHandle, _FS_IOC_GETFLAGS, &flags)
        }
        return .init(rawValue: flags)
    }


    package func setFileInodeFlags(_ flags: LinuxInodeFlags) throws(LowLevelError) {
        var flags = flags.rawValue
        try execThrowingCFunction {
            return ioctl(unsafeRawHandle, _FS_IOC_SETFLAGS, &flags)
        }
    }

    #endif

}



extension UnsafeSystemHandle {

    #if canImport(WinSDK)

    package func securityInfo(_ members: FileOperationOptions.WindowsSecurityInfoMembers) throws(LowLevelError) -> WindowsSelfRelativeSecurityDescriptor {

        var psd = nil as PSECURITY_DESCRIPTOR?

        try execThrowingCFunction {
            GetSecurityInfo(
                unsafeRawHandle, SE_FILE_OBJECT, members.rawValue,
                nil, nil, nil, nil, &psd
            )
        } onError: { (code) throws(LowLevelError) in
            if let error = LowLevelError(rawSystemCode: code) {
                throw error
            }
        }

        precondition(psd != nil, "Read security descriptor success but returned null pointer")

        return .init(psd: .init(owningPointer: psd!.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), allocator: .localAlloc))

    }


    package func setSecurityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers,
        dacl: WindowsRawAcl.View?, 
        sacl: WindowsRawAcl.View?, 
        owner: WindowsSid?, 
        group: WindowsSid?
    ) throws(LowLevelError) {

        guard !members.isEmpty else { return }

        try execThrowingCFunction { 
            SetSecurityInfo(
                unsafeRawHandle, SE_FILE_OBJECT, members.rawValue, 
                owner?.psid.unsafeResourcePtr, group?.psid.unsafeResourcePtr, 
                dacl?.pacl.unsafelyCastedMutableRawPtr, sacl?.pacl.unsafelyCastedMutableRawPtr
            )
        } onError: { (code) throws(LowLevelError) in
            if let error = LowLevelError(rawSystemCode: code) {
                throw error
            }
        }

    }

    #else
    
    package func posixPermissions() throws(LowLevelError) -> FilePermissions {
        return try .init(rawValue: fstat().st_mode & 0o7777)
    }
    

    package func setPosixPermissions(_ permissions: FilePermissions) throws(LowLevelError) {
        try execThrowingCFunction {
            fchmod(unsafeRawHandle, permissions.rawValue)
        }
    }

    #endif

}



extension UnsafeSystemHandle {
    
    package func owner() throws(LowLevelError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        
        #if canImport(WinSDK)
        
        let sd = try securityInfo([.owner, .group])

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
        
        let st = try fstat()
        
        return (
            owner: .init(rawId: st.st_uid, platformKind: .user),
            group: .init(rawId: st.st_gid, platformKind: .group)
        )
        
        #endif
        
    }
    
    
    package func fchown(owner: PlatformIdentity?, group: PlatformIdentity?) throws(LowLevelError) {
        
        #if canImport(WinSDK)
        
        var settingMembers = [] as FileOperationOptions.WindowsSecurityInfoMembers
        if owner != nil {
            settingMembers.insert(.owner)
        }
        if group != nil {
            settingMembers.insert(.group)
        }
        guard !settingMembers.isEmpty else { return }
        
        try setSecurityInfo(settingMembers, dacl: nil, sacl: nil, owner: owner?.rawId, group: group?.rawId)
        
        #else
        
        if owner == nil && group == nil { return }
        
        precondition(owner?.platformKind != .group, "owner identity must be of user kind")
        precondition(group?.platformKind != .user, "group identity must be of group kind")
        
        try execThrowingCFunction {
            PlatformCLib.fchown(unsafeRawHandle, owner?.rawId ?? .init(bitPattern: -1), group?.rawId ?? .init(bitPattern: -1))
        }
        
        #endif
        
    }
    
}

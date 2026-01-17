import SystemPackage
import PlatformCLib



extension UnsafeSystemHandle {

    func fileInfo() throws(SystemError) -> FileInfo {

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

    func type() throws(SystemError) -> FileType {

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
    fileprivate func type(prefetchedAttributes: DWORD) throws(SystemError) -> FileType {

        SetLastError(DWORD(NO_ERROR))
        let fileTypeFlags = GetFileType(unsafeRawHandle)
        try SystemError.check()

        var isSimLink: Bool {
            get throws(SystemError) {
                guard prefetchedAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 else {
                    return false
                }
                var fileAttributeTagInfo = _FILE_ATTRIBUTE_TAG_INFO()
                let structSize = DWORD(MemoryLayout<_FILE_ATTRIBUTE_TAG_INFO>.size)
                try execThrowingCFunction {
                    GetFileInformationByHandleEx(unsafeRawHandle, FileAttributeTagInfo, &fileAttributeTagInfo, structSize)
                }
                return fileAttributeTagInfo.ReparseTag == IO_REPARSE_TAG_SYMLINK
            }
        }

        var hasDirectoryFlag: Bool {
            return (prefetchedAttributes & .init(FILE_ATTRIBUTE_DIRECTORY)) != 0
        }

        return switch fileTypeFlags {
            case .init(FILE_TYPE_DISK) where try isSimLink:     .symlink
            case .init(FILE_TYPE_DISK) where hasDirectoryFlag:  .directory
            case .init(FILE_TYPE_DISK):                         .regular
            case .init(FILE_TYPE_CHAR):                         .character
            case .init(FILE_TYPE_PIPE):                         .fifo
            default:                                            .unknown
        }

    }
    #endif 

}



extension UnsafeSystemHandle {

    func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(SystemError) {

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


    func fileTimes() throws(SystemError) -> FileTimes {

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

    func fileAttributes() throws(SystemError) -> PlatformFileAttributes {
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

    func setFileAttributes(_ attributes: PlatformFileAttributes) throws(SystemError) {

        #if canImport(WinSDK)

        var basicInfo = FILE_BASIC_INFO(
            CreationTime: .init(QuadPart: -1), 
            LastAccessTime: .init(QuadPart: -1), 
            LastWriteTime: .init(QuadPart: -1), 
            ChangeTime: .init(QuadPart: -1), 
            FileAttributes: attributes.rawValue
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
    func setFileAttributes(_ attributes: PlatformFileAttributes) throws(SystemError) {
        throw SystemError(code: .extended(.notImplemented))!
    }


    func fileInodeFlags() throws(SystemError) -> CInterop.PosixInodeFlags {
        var flags: CInterop.PosixInodeFlags = 0
        try execThrowingCFunction {
            ioctl(unsafeRawHandle, _FS_IOC_GETFLAGS, &flags)
        }
        return flags
    }


    func setFileInodeFlags(_ flags: CInterop.PosixInodeFlags) throws(SystemError) {
        var flags = flags
        try execThrowingCFunction {
            return ioctl(unsafeRawHandle, _FS_IOC_SETFLAGS, &flags)
        }
    }

    #endif

}



extension UnsafeSystemHandle {

    #if canImport(WinSDK)

    func securityInfo(_ members: FileOperationOptions.WindowsSecurityInfoMembers) throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {

        var psd = nil as PSECURITY_DESCRIPTOR?

        try execThrowingCFunction {
            GetSecurityInfo(
                unsafeRawHandle, SE_FILE_OBJECT, members.rawValue,
                nil, nil, nil, nil, &psd
            )
        } onError: { (code) throws(SystemError) in
            if let error = SystemError(code: code) {
                throw error
            }
        }

        precondition(psd != nil, "Read security descriptor success but returned null pointer")

        return .init(psd: .init(owningPointer: psd!.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), allocator: .localAlloc))

    }


    func setSecurityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers,
        dacl: consuming WindowsRawAcl?, 
        sacl: consuming WindowsRawAcl?, 
        owner: WindowsSid?, 
        group: WindowsSid?
    ) throws(SystemError) {

        guard !members.isEmpty else { return }

        try execThrowingCFunction { 
            SetSecurityInfo(
                unsafeRawHandle, SE_FILE_OBJECT, members.rawValue, 
                owner?.psid.unsafeResourcePtr, group?.psid.unsafeResourcePtr, 
                dacl?.pacl.unsafelyCastedMutableRawPtr, sacl?.pacl.unsafelyCastedMutableRawPtr
            )
        } onError: { (code) throws(SystemError) in
            if let error = SystemError(code: code) {
                throw error
            }
        }

    }

    #else 

    func setPermissions(_ permissions: FilePermissions) throws(SystemError) {
        try execThrowingCFunction {
            fchmod(unsafeRawHandle, permissions.rawValue)
        }
    }

    #endif

}
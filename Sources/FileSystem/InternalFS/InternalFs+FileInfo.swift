import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    static func getFileInfo(forItemAt path: FilePath, followSymlink: Bool = false) throws(SystemError) -> FileInfo {

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

        return try getRawFileInfo(from: handle)

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

    static func type(ofItemAt path: FilePath) throws(SystemError) -> FileType {
        
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
            } catch let e where e.kind == .notFound || e.kind == .nameTooLong || e.code == .platform(.invalidFileName) {
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

        return try type(ofHandle: handle)

        #else 

        return .init(mode: try ulstat(path).st_mode)

        #endif

    }

}



// MARK: - Times
extension InternalFS {

    static func setFileTimes(
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
        try setFileTimes(for: handle, access: access, modification: modification, creation: creation)
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


    static func getFileTimes(
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
        
        let times = try getFileTimes(from: handle)

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

    static func getFileAttributes(forItemAt path: FilePath) throws(SystemError) -> PlatformFileAttributes {
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

    static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(SystemError) {

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
    static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(SystemError) {
        throw SystemError(code: .notSupported)!
    }


    static func setFileInodeFlags(forItemAt path: FilePath, flags: CInterop.PosixInodeFlags) throws(SystemError) {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        try fd.setFileInodeFlags(flags)
        try fd.close()
    }


    static func readFileInodeFlags(forItemAt path: FilePath) throws(SystemError) -> CInterop.PosixInodeFlags {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        let flags = try fd.fileInodeFlags()
        try fd.close()
        return flags
    }


    static func fileAttributesToInodeFlags(_ attributes: PlatformFileAttributes) -> CInterop.PosixInodeFlags {
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

    #if canImport(WinSDK)

    static func setFileSecurityInfo(
        forItemAt path: FilePath, 
        setting members: WindowsSecurityInfoMembers,
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


    static func getSecurityInfo(forItemAt path: FilePath, members: WindowsSecurityInfoMembers) throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {
        
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

    static func setFilePermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(SystemError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                fchmodat(AT_FDCWD, pathPtr, permissions.rawValue, AT_SYMLINK_NOFOLLOW)
            }
        }
    }

    #endif 

}
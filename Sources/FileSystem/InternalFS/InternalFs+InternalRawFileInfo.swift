import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    struct InternalRawFileInfo {

        let type: FileType
        let size: UInt64
        let fileId: CInterop.FileId
        let deviceId: CInterop.DeviceId

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

        #if !canImport(WinSDK)
        let permissions: FilePermissions
        let uid: UInt32
        let gid: UInt32
        #endif

    }


    struct InternalFileTimes {
        var accessTime: CInterop.PlatformFileTime
        var modificationTime: CInterop.PlatformFileTime
        var changeTime: CInterop.PlatformFileTime
        #if canImport(Darwin) || canImport(WinSDK) || os(FreeBSD) || os(OpenBSD)
        var creationTime: CInterop.PlatformFileTime
        #else 
        var creationTime: CInterop.PlatformFileTime?
        #endif
    }


    static func getRawFileInfo(forItemAt path: FilePath, followSymlink: Bool = false) throws(SystemError) -> InternalRawFileInfo {

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
                    type: type, 
                    size: .init(infoByName.EndOfFile.QuadPart), 
                    fileId: infoByName.FileId128.uint128, 
                    deviceId: .init(infoByName.VolumeSerialNumber.QuadPart), 
                    accessTime: .init(dwLowDateTime: infoByName.LastAccessTime.LowPart, dwHighDateTime: .init(bitPattern: infoByName.LastAccessTime.HighPart)), 
                    modificationTime: .init(dwLowDateTime: infoByName.LastWriteTime.LowPart, dwHighDateTime: .init(bitPattern: infoByName.LastWriteTime.HighPart)), 
                    changeTime: .init(dwLowDateTime: infoByName.ChangeTime.LowPart, dwHighDateTime: .init(bitPattern: infoByName.ChangeTime.HighPart)), 
                    creationTime: .init(dwLowDateTime: infoByName.CreationTime.LowPart, dwHighDateTime: .init(bitPattern: infoByName.CreationTime.HighPart)), 
                    attributes: infoByName.FileAttributes
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

        return .init(from: st)

        #endif 

    }


    static func getRawFileInfo(from handle: borrowing UnsafeSystemHandle) throws(SystemError) -> InternalRawFileInfo {

        #if canImport(WinSDK)

        var fileStandardInfo = FILE_STANDARD_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(handle.unsafeRawHandle, FileStandardInfo, &fileStandardInfo, DWORD(MemoryLayout<FILE_STANDARD_INFO>.size))
        }

        var fileBasicInfo = FILE_BASIC_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                handle.unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        let type = try type(ofHandle: handle, prefetchedAttributes: fileBasicInfo.FileAttributes)

        var fileIdInfo = FILE_ID_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                handle.unsafeRawHandle, FileIdInfo, &fileIdInfo, DWORD(MemoryLayout<FILE_ID_INFO>.size)
            )
        }

        return .init(
            type: type, 
            size: .init(fileStandardInfo.EndOfFile.QuadPart), 
            fileId: fileIdInfo.FileId.uint128, 
            deviceId: fileIdInfo.VolumeSerialNumber, 
            accessTime: .init(largeInteger: fileBasicInfo.LastAccessTime), 
            modificationTime: .init(largeInteger: fileBasicInfo.LastWriteTime), 
            changeTime: .init(largeInteger: fileBasicInfo.ChangeTime), 
            creationTime: .init(largeInteger: fileBasicInfo.CreationTime), 
            attributes: fileBasicInfo.FileAttributes
        )

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


    static func type(ofHandle handle: borrowing UnsafeSystemHandle) throws(SystemError) -> FileType {

        #if canImport(WinSDK)

        var fileBasicInfo = FILE_BASIC_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                handle.unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        return try type(ofHandle: handle, prefetchedAttributes: fileBasicInfo.FileAttributes)

        #else

        return try .init(mode: try ufstat(handle.unsafeRawHandle).st_mode)

        #endif

    }


    #if canImport(WinSDK)
    static func type(ofHandle handle: borrowing UnsafeSystemHandle, prefetchedAttributes: DWORD) throws(SystemError) -> FileType {

        SetLastError(DWORD(NO_ERROR))
        let fileTypeFlags = GetFileType(handle.unsafeRawHandle)
        try SystemError.check()

        var isSimLink: Bool {
            get throws(SystemError) {
                guard prefetchedAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 else {
                    return false
                }
                var fileAttributeTagInfo = _FILE_ATTRIBUTE_TAG_INFO()
                let structSize = DWORD(MemoryLayout<_FILE_ATTRIBUTE_TAG_INFO>.size)
                try execThrowingCFunction {
                    GetFileInformationByHandleEx(handle.unsafeRawHandle, FileAttributeTagInfo, &fileAttributeTagInfo, structSize)
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

        try utimes(for: path, creation: creation, access: access, modify: modification)

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

        try futimes(for: handle, creation: creation, access: access, modify: modification)

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


    static func getFileTimes(
        fromItemAt path: FilePath
    ) throws(SystemError) -> InternalFileTimes {

        #if canImport(WinSDK)

        if let getFileInformationByNamePtr = getGetFileInformationByNameFuncPtr() {

            var fileInfo =  FILE_STAT_INFORMATION()

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in 
                    getFileInformationByNamePtr(pathPtr, FileStatByNameInfo, &fileInfo, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size)).boolValue
                }
            }

            return .init(
                accessTime: .init(largeInteger: fileInfo.LastAccessTime), 
                modificationTime: .init(largeInteger: fileInfo.LastWriteTime), 
                changeTime: .init(largeInteger: fileInfo.ChangeTime),
                creationTime: .init(largeInteger: fileInfo.CreationTime)
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

        let internalInfo = try getRawFileInfo(forItemAt: path, followSymlink: followSymlink)
        return .init(
            accessTime: internalInfo.accessTime, 
            modificationTime: internalInfo.modificationTime, 
            changeTime: internalInfo.changeTime,
            creationTime: internalInfo.creationTime
        )

        #endif 

    }


    static func getFileTimes(
        from handle: borrowing UnsafeSystemHandle
    ) throws(SystemError) -> InternalFileTimes {

        #if canImport(WinSDK)

        var fileBasicInfo = FILE_BASIC_INFO()

        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                handle.unsafeRawHandle, FileBasicInfo, &fileBasicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

        let times = InternalFileTimes(
            accessTime: .init(largeInteger: fileBasicInfo.LastAccessTime), 
            modificationTime: .init(largeInteger: fileBasicInfo.LastWriteTime), 
            changeTime: .init(largeInteger: fileBasicInfo.ChangeTime),
            creationTime: .init(largeInteger: fileBasicInfo.CreationTime)
        )

        return times

        #else

        let internalInfo = try getRawFileInfo(from: handle)
        return .init(
            accessTime: internalInfo.accessTime, 
            modificationTime: internalInfo.modificationTime, 
            changeTime: internalInfo.changeTime,
            creationTime: internalInfo.creationTime
        )

        #endif 

    }

}



// MARK: - Attributes & Flags
extension InternalFS {

    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    static func setFileAttributes(forItemAt path: FilePath, attributes: CInterop.PlatformFileAttribute) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                SetFileAttributesW(pathPtr, attributes)
            }
        }

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

        var basicInfo = FILE_BASIC_INFO(
            CreationTime: .init(QuadPart: -1), 
            LastAccessTime: .init(QuadPart: -1), 
            LastWriteTime: .init(QuadPart: -1), 
            ChangeTime: .init(QuadPart: -1), 
            FileAttributes: attributes
        )

        try execThrowingCFunction {
            SetFileInformationByHandle(
                handle.unsafeRawHandle, FileBasicInfo, &basicInfo, DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            )
        }

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

    static func setFilePermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(SystemError) {
        let daclPtr = try WindowsAPI.dacl(fromPosixPermissions: permissions)
        try setFileSecurityInfo(
            forItemAt: path, 
            settring: .dacl, 
            dacl: .init(pacl: daclPtr), sacl: nil, owner: nil, group: nil
        )
    }


    static func setFilePermissions(for handle: borrowing UnsafeSystemHandle, permissions: FilePermissions) throws(SystemError) {
        let daclPtr = try WindowsAPI.dacl(fromPosixPermissions: permissions)
        try setFileSecurityInfo(
            for: handle, 
            settring: .dacl, 
            dacl: .init(pacl: daclPtr), sacl: nil, owner: nil, group: nil
        )
    }


    struct WindowsSecurityInfoMembers: OptionSet {
        let rawValue: DWORD
        static let owner: Self = .init(rawValue: DWORD(OWNER_SECURITY_INFORMATION))
        static let group: Self = .init(rawValue: DWORD(GROUP_SECURITY_INFORMATION))
        static let dacl: Self = .init(rawValue: DWORD(DACL_SECURITY_INFORMATION))
        static let sacl: Self = .init(rawValue: DWORD(SACL_SECURITY_INFORMATION))
        static var all: Self { [.owner, .group, .dacl, .sacl] }
    }


    static func setFileSecurityInfo(
        forItemAt path: FilePath, 
        settring members: WindowsSecurityInfoMembers,
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
                    dacl?.pacl.unsafeRawPtr, sacl?.pacl.unsafeRawPtr
                )
            }
        } onError: { (code) throws(SystemError) in
            if let error = SystemError(code: code) {
                throw error
            }
        }

    }


    static func setFileSecurityInfo(
        for handle: borrowing UnsafeSystemHandle, 
        settring members: WindowsSecurityInfoMembers,
        dacl: consuming WindowsRawAcl?, 
        sacl: consuming WindowsRawAcl?, 
        owner: WindowsSid?, 
        group: WindowsSid?
    ) throws(SystemError) {

        guard !members.isEmpty else { return }

        try execThrowingCFunction { 
            SetSecurityInfo(
                handle.unsafeRawHandle, SE_FILE_OBJECT, members.rawValue, 
                owner?.psid.unsafeResourcePtr, group?.psid.unsafeResourcePtr, 
                dacl?.pacl.unsafeRawPtr, sacl?.pacl.unsafeRawPtr
            )
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


    static func getSecurityInfo(for handle: borrowing UnsafeSystemHandle, members: WindowsSecurityInfoMembers) throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {

        var psd = nil as PSECURITY_DESCRIPTOR?

        try execThrowingCFunction {
            GetSecurityInfo(
                handle.unsafeRawHandle, SE_FILE_OBJECT, members.rawValue,
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
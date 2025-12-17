import PlatformCLib
import SystemPackage
import CFileSystem



public struct FileInfo: Sendable, Equatable, Hashable {

    public let path: FilePath
    public let size: UInt64

    public let type: FileType

    public let lastAccessDate: PlatformTimeSpec
    public let lastModificationDate: PlatformTimeSpec
    public let lastStatusChangeDate: PlatformTimeSpec
    public let creationDate: PlatformTimeSpec?

    public let securityInfo: PlatformSecurityInfo

    public let attributes: PlatformAttributes
    public let supportedAttributes: PlatformAttributes

}



extension FileInfo: CustomStringConvertible {

    @inlinable
    public var description: String {
        """
        File(\
        path: \(path), type: \(type), size: \(size) bytes, \
        last accessed: \(lastAccessDate), \
        last modified: \(lastModificationDate), \
        last status changed: \(lastStatusChangeDate), \
        \(creationDate.map { "created: \($0)," } ?? "") \
        security: \(securityInfo), \
        attributes: \(attributes))
        """
    }

}



extension FileInfo {

#if canImport(WinSDK)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {

        if let GetFileInformationByNameFuncPtr = getGetFileInformationByNameFuncPtr() {

            // A faster path for getting information of files without opening a handle

            var fileInformationByName = FILE_STAT_INFORMATION()

            try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
                path.string.withCString(encodedAs: UTF16.self) { pathPtr in 
                    GetFileInformationByNameFuncPtr(pathPtr, FileStatByNameInfo, &fileInformationByName, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size)).boolValue
                }
            }

            if followSymLink && fileInformationByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                let destPathPtr = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                    try WindowsAPI.destinationPathOfSymbolicLink(at: path)
                }
                try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
                    GetFileInformationByNameFuncPtr(destPathPtr.unsafeRawPtr, FileStatByNameInfo, &fileInformationByName, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size)).boolValue
                }
            }

            let type = if fileInformationByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                .symlink
            } else if (fileInformationByName.FileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                .directory
            } else {
                .regular
            } as FileType

            let securityDescriptorPtr = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                try WindowsAPI.getFileSecurity(at: path, requesting: DWORD(OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION))
            }

            let ownerSidStr = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                let (ownerSidPtr, _) = try WindowsAPI.getOwnerSid(from: securityDescriptorPtr.unownedView())
                return try WindowsAPI.pSidToString(sidPtr: ownerSidPtr)
            }

            let groupSidStr = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                let (groupSidPtr, _) = try WindowsAPI.getGroupSid(from: securityDescriptorPtr.unownedView())
                return try WindowsAPI.pSidToString(sidPtr: groupSidPtr)
            }

            self.init(
                path: path, 
                size: UInt64(fileInformationByName.EndOfFile.QuadPart), 
                type: type, 
                lastAccessDate: .init(platformFileTime: fileInformationByName.LastAccessTime), 
                lastModificationDate: .init(platformFileTime: fileInformationByName.LastWriteTime), 
                lastStatusChangeDate: .init(platformFileTime: fileInformationByName.ChangeTime), 
                creationDate: .init(platformFileTime: fileInformationByName.CreationTime), 
                securityInfo: .init(effectiveAccess: .init(rawValue: fileInformationByName.EffectiveAccess), owner: ownerSidStr, group: groupSidStr), 
                attributes: .init(rawValue: fileInformationByName.FileAttributes), 
                supportedAttributes: .all
            )

        } else {

            let handle = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                try UnsafeSystemHandle.open(
                    at: path, 
                    openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: !followSymLink)
                )
            }

            self = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
                try .init(unsafeSystemHandle: handle, path: path)
            }

        }

    }


    init(unsafeSystemHandle handle: borrowing UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        var infoByHandle = _BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(handle.unsafeRawHandle, &infoByHandle) else {
            try SystemError.assertError()
        }

        self.path = path
        self.size = (UInt64(infoByHandle.nFileSizeHigh) << 32) | UInt64(infoByHandle.nFileSizeLow)
        self.attributes = .init(rawValue: infoByHandle.dwFileAttributes)
        self.supportedAttributes = .all
        self.creationDate = .init(platformFileTime: infoByHandle.ftCreationTime)
        self.lastAccessDate = .init(platformFileTime: infoByHandle.ftLastAccessTime)
        self.lastModificationDate = .init(platformFileTime: infoByHandle.ftLastWriteTime)
        self.lastStatusChangeDate = .init(platformFileTime: infoByHandle.ftLastWriteTime)

        self.type = try catchSystemError { () throws(SystemError) in
            try .init(unsafeFromFileHandle: handle.unsafeRawHandle, attributes: infoByHandle.dwFileAttributes)
        }

        var securityDescriptorPtr = nil as PSECURITY_DESCRIPTOR?
        var ownerSidPtr = nil as PSID?
        var groupSidPtr = nil as PSID?
        try execThrowingCFunction {
            GetSecurityInfo(
                handle.unsafeRawHandle, SE_FILE_OBJECT, 
                DWORD(OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION), 
                &ownerSidPtr, &groupSidPtr, nil, nil, 
                &securityDescriptorPtr
            )
        } onError: { (code) throws(FileError) in
            throw SystemError(code: code)
        }
        guard let securityDescriptorPtr else {
            try SystemError.assertError()
        }
        defer { LocalFree(securityDescriptorPtr) }
        guard let ownerSidPtr, let groupSidPtr else {
            try SystemError.assertError()
        }

        let ownerSidStr = try catchSystemError { () throws(SystemError) in
            try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: ownerSidPtr))
        }
        let groupSidStr = try catchSystemError { () throws(SystemError) in
            try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: groupSidPtr))
        }

        let effectiveAccessMask = try catchSystemError { () throws(SystemError) in
            try WindowsAPI.effectiveAccessMaskForCurrentProcess(from: .init(unownedPointer: securityDescriptorPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self)))
        }

        self.securityInfo = .init(effectiveAccess: .init(rawValue: effectiveAccessMask), owner: ownerSidStr, group: groupSidStr)

    }

#elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        self = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try .make(forItemAt: path, followSymLink: followSymLink)
        }
    }


    static func make(forItemAt path: FilePath, followSymLink: Bool) throws(SystemError) -> FileInfo {
        
        let rawInfo = try InternalFS.getRawFileInfo(forItemAt: path, followSymlink: followSymLink)

        return .init(
            path: path, 
            size: rawInfo.size, 
            type: rawInfo.type, 
            lastAccessDate: .init(platformFileTime: rawInfo.accessTime), 
            lastModificationDate: .init(platformFileTime: rawInfo.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: rawInfo.changeTime), 
            creationDate: .init(platformFileTime: rawInfo.creationTime), 
            securityInfo: .init(permission: rawInfo.permissions, uid: rawInfo.uid, gid: rawInfo.gid), 
            attributes: .init(rawValue: rawInfo.attributes), 
            supportedAttributes: .all
        )

    }


    init(unsafeSystemHandle handle: borrowing UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        let rawInfo = try InternalFS.getRawFileInfo(from: handle)

        self = .init(
            path: path, 
            size: rawInfo.size, 
            type: rawInfo.type, 
            lastAccessDate: .init(platformFileTime: rawInfo.accessTime), 
            lastModificationDate: .init(platformFileTime: rawInfo.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: rawInfo.changeTime), 
            creationDate: .init(platformFileTime: rawInfo.creationTime), 
            securityInfo: .init(permission: rawInfo.permissions, uid: rawInfo.uid, gid: rawInfo.gid), 
            attributes: .init(rawValue: rawInfo.attributes), 
            supportedAttributes: .all
        )

    }

#elseif canImport(Glibc) || canImport(Musl)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        self = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try .make(forItemAt: path, followSymLink: followSymLink)
        }
    }


    static func make(forItemAt path: FilePath, followSymLink: Bool) throws(SystemError) -> FileInfo {

        var stat = StatCompat()
        let flags = followSymLink ? 0 : AT_SYMLINK_NOFOLLOW

        try execThrowingCFunction {
            systemStatCompat(path.string, flags, &stat)
        }

        return .init(
            path: path,
            size: UInt64(stat.st_size),
            type: .init(mode: stat.st_mode),
            lastAccessDate: .init(platformFileTime: stat.st_atim),
            lastModificationDate: .init(platformFileTime: stat.st_mtim),
            lastStatusChangeDate: .init(platformFileTime: stat.st_ctim),
            creationDate: (stat.has_btime != 0) ? .init(platformFileTime: stat.st_btim) : nil,
            securityInfo: .init(permission: .init(rawValue: stat.st_mode & 0o7777), uid: stat.st_uid, gid: stat.st_gid),
            attributes: .init(rawValue: stat.st_attributes),
            supportedAttributes: .init(rawValue: stat.st_attributes_mask)
        )

    }


    init(unsafeSystemHandle handle: borrowing UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        var stat = StatCompat()

        try execThrowingCFunction {
            systemFStatCompat(handle.unsafeRawHandle, &stat)
        }

        self.path = path
        self.size = UInt64(stat.st_size)

        self.lastAccessDate = .init(platformFileTime: stat.st_atim)
        self.lastModificationDate = .init(platformFileTime: stat.st_mtim)
        self.lastStatusChangeDate = .init(platformFileTime: stat.st_ctim)
        if (stat.has_btime != 0) {
            self.creationDate = .init(platformFileTime: stat.st_btim)
        } else {
            self.creationDate = nil
        }

        self.type = .init(mode: stat.st_mode)

        self.attributes = .init(rawValue: stat.st_attributes)
        self.supportedAttributes = .init(rawValue: stat.st_attributes_mask)

        self.securityInfo = .init(permission: .init(rawValue: stat.st_mode & 0o7777), uid: stat.st_uid, gid: stat.st_gid)

        // TODO: on older linux kernels, try to use ioctl with FS_IOC_GETFLAGS to get file attributes

    }

#endif

}
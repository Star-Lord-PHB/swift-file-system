
import Foundation
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

        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | (followSymLink ? 0 : DWORD(FILE_FLAG_OPEN_REPARSE_POINT))
        
        let handle = path.string.withCString(encodedAs: UTF16.self) { cPath in 
            CreateFileW(cPath, DWORD(FILE_READ_ATTRIBUTES | READ_CONTROL), .init(FILE_SHARE_READ), nil, .init(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try FileError.assertError(operationDescription: .fetchingInfo(for: path))
        }

        defer { CloseHandle(handle) }

        try self.init(unsafeSystemHandle: handle, path: path)

    }


    init(unsafeSystemHandle: WinSDK.HANDLE, path: FilePath) throws(FileError) {

        var infoByHandle = _BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(unsafeSystemHandle, &infoByHandle) else {
            try FileError.assertError(operationDescription: .fetchingInfo(for: path))
        }

        self.path = path
        self.size = (UInt64(infoByHandle.nFileSizeHigh) << 32) | UInt64(infoByHandle.nFileSizeLow)
        self.attributes = .init(rawValue: infoByHandle.dwFileAttributes)
        self.supportedAttributes = .all
        self.creationDate = .init(platformFileTime: infoByHandle.ftCreationTime)
        self.lastAccessDate = .init(platformFileTime: infoByHandle.ftLastAccessTime)
        self.lastModificationDate = .init(platformFileTime: infoByHandle.ftLastWriteTime)
        self.lastStatusChangeDate = .init(platformFileTime: infoByHandle.ftLastWriteTime)

        self.type = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try .init(unsafeFromFileHandle: unsafeSystemHandle, attributes: infoByHandle.dwFileAttributes)
        }

        var securityDescriptorPtr = nil as PSECURITY_DESCRIPTOR?
        try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
            GetSecurityInfo(
                unsafeSystemHandle, SE_FILE_OBJECT, 
                DWORD(OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION), 
                nil, nil, nil, nil, 
                &securityDescriptorPtr
            )
        }
        guard let securityDescriptorPtr else {
            try FileError.assertError(operationDescription: .fetchingInfo(for: path))
        }
        defer { LocalFree(securityDescriptorPtr) }

        self.securityInfo = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in 
            try .init(unsafeFromSecurityDescriptorPtr: securityDescriptorPtr)
        }

    }

#elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {

        let openFlags = followSymLink ? 0 : AT_SYMLINK_NOFOLLOW

        var stat = stat()

        try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
            fstatat(AT_FDCWD, path.string, &stat, openFlags)
        }

        self.path = path
        self.size = UInt64(stat.st_size)

        self.lastAccessDate = .init(platformFileTime: stat.st_atimespec)
        self.lastModificationDate = .init(platformFileTime: stat.st_mtimespec)
        self.lastStatusChangeDate = .init(platformFileTime: stat.st_ctimespec)
        self.creationDate = .init(platformFileTime: stat.st_birthtimespec)

        self.attributes = .init(rawValue: stat.st_flags)
        self.supportedAttributes = .all

        self.type = .init(mode: stat.st_mode)

        self.securityInfo = .init(permission: .init(rawValue: stat.st_mode), uid: stat.st_uid, gid: stat.st_gid)

    }


    init(unsafeSystemHandle: CInt, path: FilePath) throws(FileError) {

        var stat = stat()

        try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
            fstat(unsafeSystemHandle, &stat)
        }

        self.path = path
        self.size = UInt64(stat.st_size)

        self.lastAccessDate = .init(platformFileTime: stat.st_atimespec)
        self.lastModificationDate = .init(platformFileTime: stat.st_mtimespec)
        self.lastStatusChangeDate = .init(platformFileTime: stat.st_ctimespec)
        self.creationDate = .init(platformFileTime: stat.st_birthtimespec)

        self.attributes = .init(rawValue: stat.st_flags)
        self.supportedAttributes = .all

        self.type = .init(mode: stat.st_mode)

        self.securityInfo = .init(permission: .init(rawValue: stat.st_mode), uid: stat.st_uid, gid: stat.st_gid)

    }

#elseif canImport(Glibc) || canImport(Musl)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        
        let openFlags = followSymLink ? O_RDONLY : (O_RDONLY | __O_PATH | O_NOFOLLOW)
        let fd = open(path.string, openFlags)
        guard fd >= 0 else {
            try FileError.assertError(operationDescription: .fetchingInfo(for: path))
        }
        defer { close(fd) }

        try self.init(unsafeSystemHandle: fd, path: path)

    }


    init(unsafeSystemHandle: CInt, path: FilePath) throws(FileError) {

        var stat = StatCompat()

        try execThrowingCFunction(operationDescription: .fetchingInfo(for: path)) {
            systemStatCompat(unsafeSystemHandle, &stat)
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

        self.securityInfo = .init(permission: .init(rawValue: stat.st_mode), uid: stat.st_uid, gid: stat.st_gid)

        // TODO: on older linux kernels, try to use ioctl with FS_IOC_GETFLAGS to get file attributes

    }

#endif

}
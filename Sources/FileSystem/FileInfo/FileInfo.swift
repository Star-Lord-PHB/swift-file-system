import PlatformCLib
import SystemPackage
import CFileSystem



public struct FileInfo: Sendable, Equatable, Hashable {

    public let path: FilePath
    public let size: UInt64

    public let type: FileType

    public let lastAccessDate: FileTimeSpec
    public let lastModificationDate: FileTimeSpec
    public let lastStatusChangeDate: FileTimeSpec
    public let creationDate: FileTimeSpec?

    public let fileIdentifier: FileIdentifier

    #if !canImport(WinSDK)
    public let permissions: FilePermissions
    public let uid: UInt32
    public let gid: UInt32
    #endif

    public let attributes: PlatformFileAttributes
    public let supportedAttributes: PlatformFileAttributes

}



extension FileInfo: CustomStringConvertible {

    @inlinable
    public var description: String {
        var str = """
            File(\
            path: \(path), type: \(type), size: \(size) bytes, \
            last accessed: \(lastAccessDate), \
            last modified: \(lastModificationDate), \
            last status changed: \(lastStatusChangeDate), \
            \(creationDate.map { "created: \($0)," } ?? "") \
            attributes: \(attributes))
            """
        #if !canImport(WinSDK)
        str += ", permissions: \(permissions), uid: \(uid), gid: \(gid)"
        #endif
        return str
    }

}



extension FileInfo {

#if canImport(WinSDK)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {

        let info = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try InternalFS.getRawFileInfo(forItemAt: path, followSymlink: followSymLink)
        }

        self.init(
            path: path, 
            size: info.size, 
            type: info.type, 
            lastAccessDate: .init(platformFileTime: info.accessTime), 
            lastModificationDate: .init(platformFileTime: info.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: info.changeTime), 
            creationDate: .init(platformFileTime: info.creationTime), 
            fileIdentifier: .init(fileId: info.fileId, deviceId: info.deviceId),
            attributes: .init(rawValue: info.attributes), 
            supportedAttributes: .all
        )

    }


    init(unsafeSystemHandle handle: borrowing UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        let info = try InternalFS.getRawFileInfo(from: handle)

        self.init(
            path: path, 
            size: info.size, 
            type: info.type, 
            lastAccessDate: .init(platformFileTime: info.accessTime), 
            lastModificationDate: .init(platformFileTime: info.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: info.changeTime), 
            creationDate: .init(platformFileTime: info.creationTime), 
            fileIdentifier: .init(fileId: info.fileId, deviceId: info.deviceId),
            attributes: .init(rawValue: info.attributes), 
            supportedAttributes: .all
        )

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
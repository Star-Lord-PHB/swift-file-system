import PlatformCLib
import SystemPackage
import CFileSystem



public struct FileInfo: Sendable, Equatable, Hashable {

    // public let path: FilePath
    public let size: UInt64

    public let type: FileType

    public let times: FileTimes

    public let fileIdentifier: FileIdentifier

    #if !canImport(WinSDK)
    public let permissions: FilePermissions
    public let owner: PlatformIdentity
    public let group: PlatformIdentity
    #endif

    public let attributes: PlatformFileAttributes
    public let supportedAttributes: PlatformFileAttributes

}



extension FileInfo: CustomStringConvertible {

    @inlinable
    public var description: String {
        var str = """
            File(\
            type: \(type), size: \(size) bytes, \
            last accessed: \(times.lastAccess), \
            last modified: \(times.lastModification), \
            last status changed: \(times.lastChange), \
            \(times.creation.map { "created: \($0)," } ?? "") \
            attributes: \(attributes))
            """
        #if !canImport(WinSDK)
        str += ", permissions: \(permissions), owner: \(owner), group: \(group)"
        #endif
        return str
    }

}



extension FileInfo {

    #if !canImport(WinSDK)
    init(stat: CInterop.Stat) {
        self.type = .init(mode: stat.st_mode)
        self.size = .init(stat.st_size)
        self.fileIdentifier = .init(fileId: stat.st_ino, deviceId: stat.st_dev)

        #if canImport(Glibc) || canImport(Musl)
        self.times = .init(
            lastAccess: .init(platformFileTime: stat.st_atim), 
            lastModification: .init(platformFileTime: stat.st_mtim), 
            lastChange: .init(platformFileTime: stat.st_ctim), 
            creation: stat.st_btim.map { .init(platformFileTime: $0) }
        )
        #else
        self.times = .init(
            lastAccess: .init(platformFileTime: stat.st_atim), 
            lastModification: .init(platformFileTime: stat.st_mtim), 
            lastChange: .init(platformFileTime: stat.st_ctim), 
            creation: .init(platformFileTime: stat.st_btim)
        )
        #endif

        self.attributes = .init(rawValue: stat.st_flags)

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        self.supportedAttributes = .all
        #else 
        self.supportedAttributes = .init(rawValue: stat.st_flags_mask)
        #endif

        self.permissions = .init(rawValue: stat.st_mode & 0o7777)
        self.owner = .init(rawId: stat.st_uid, kind: .user)
        self.group = .init(rawId: stat.st_gid, kind: .group)
    }
    #endif

}



extension FileInfo {

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        self = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try InternalFS.getFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
    }


    init(unsafeSystemHandle handle: borrowing UnsafeSystemHandle) throws(SystemError) {
        self = try handle.fileInfo()
    }

}
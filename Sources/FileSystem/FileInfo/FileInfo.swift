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
        let rawInfo = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try InternalFS.getRawFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
        self.init(
            path: path, 
            size: rawInfo.size, 
            type: rawInfo.type, 
            lastAccessDate: .init(platformFileTime: rawInfo.accessTime), 
            lastModificationDate: .init(platformFileTime: rawInfo.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: rawInfo.changeTime), 
            creationDate: .init(platformFileTime: rawInfo.creationTime), 
            fileIdentifier: .init(fileId: rawInfo.fileId, deviceId: rawInfo.deviceId),
            permissions: rawInfo.permissions,
            uid: rawInfo.uid,
            gid: rawInfo.gid,
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
            fileIdentifier: .init(fileId: rawInfo.fileId, deviceId: rawInfo.deviceId),
            permissions: rawInfo.permissions,
            uid: rawInfo.uid,
            gid: rawInfo.gid,
            attributes: .init(rawValue: rawInfo.attributes), 
            supportedAttributes: .all
        )

    }

#elseif canImport(Glibc) || canImport(Musl)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        let rawInfo = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try InternalFS.getRawFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
        self.init(
            path: path, 
            size: rawInfo.size, 
            type: rawInfo.type, 
            lastAccessDate: .init(platformFileTime: rawInfo.accessTime), 
            lastModificationDate: .init(platformFileTime: rawInfo.modificationTime), 
            lastStatusChangeDate: .init(platformFileTime: rawInfo.changeTime), 
            creationDate: rawInfo.creationTime.map { .init(platformFileTime: $0) }, 
            fileIdentifier: .init(fileId: rawInfo.fileId, deviceId: rawInfo.deviceId),
            permissions: rawInfo.permissions,
            uid: rawInfo.uid,
            gid: rawInfo.gid,
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
            creationDate: rawInfo.creationTime.map { .init(platformFileTime: $0) }, 
            fileIdentifier: .init(fileId: rawInfo.fileId, deviceId: rawInfo.deviceId),
            permissions: rawInfo.permissions,
            uid: rawInfo.uid,
            gid: rawInfo.gid,
            attributes: .init(rawValue: rawInfo.attributes), 
            supportedAttributes: .all
        )

    }

#endif

}

import Foundation
import SystemPackage
import CFileSystem



public struct FileInfo {

    public let path: FilePath
    public let size: UInt64

    public let type: FileType

    public let lastAccessDate: TimeSpec
    public let lastModificationDate: TimeSpec
    public let lastStatusChangeDate: TimeSpec
    public let creationDate: TimeSpec?

    public let permissions: Permission

    public let owner: User

    public let attributes: Attributes
    public let supportedAttributes: Attributes

}



extension FileInfo {

#if canImport(WinSDK)

    // TODO: implement on Windows
    public init(fileAt path: FilePath, followSymLink: Bool = true) throws {
        fatalError("Not implemented")
    }

#elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {

        let openFlags = followSymLink ? 0 : AT_SYMLINK_NOFOLLOW

        var stat = stat()

        try execThrowingCFunction {
            fstatat(AT_FDCWD, path.string, &stat, openFlags)
        } onError: {
            FileError.fromErrno(operationDescription: .fetchingInfo(for: path))
        }

        self.path = path
        self.size = UInt64(stat.st_size)
        self.permissions = .init(rawValue: stat.st_mode)

        self.lastAccessDate = .init(timespec: stat.st_atimespec)
        self.lastModificationDate = .init(timespec: stat.st_mtimespec)
        self.lastStatusChangeDate = .init(timespec: stat.st_ctimespec)
        self.creationDate = .init(timespec: stat.st_birthtimespec)

        self.attributes = .init(rawValue: stat.st_flags)
        self.supportedAttributes = .all

        self.owner = .init(uid: stat.st_uid, gid: stat.st_gid)
        self.type = .init(mode: stat.st_mode)

    }

#elseif canImport(Glibc) || canImport(Musl)

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        
        let openFlags = followSymLink ? O_RDONLY : (O_RDONLY | __O_PATH | O_NOFOLLOW)
        let fd = open(path.string, openFlags)
        guard fd >= 0 else {
            throw FileError.fromErrno(operationDescription: .fetchingInfo(for: path))
        }
        defer { close(fd) }

        var stat = StatCompat()

        try execThrowingCFunction {
            systemStatCompat(fd, &stat)
        } onError: {
            FileError.fromErrno(operationDescription: .fetchingInfo(for: path))
        }

        self.path = path
        self.size = UInt64(stat.st_size)
        self.permissions = .init(rawValue: stat.st_mode)

        self.lastAccessDate = .init(timespec: stat.st_atim)
        self.lastModificationDate = .init(timespec: stat.st_mtim)
        self.lastStatusChangeDate = .init(timespec: stat.st_ctim)
        if (stat.has_btime != 0) {
            self.creationDate = .init(timespec: stat.st_btim)
        } else {
            self.creationDate = nil
        }

        self.owner = .init(uid: stat.st_uid, gid: stat.st_gid)
        self.type = .init(mode: stat.st_mode)

        self.attributes = .init(rawValue: stat.st_attributes)
        self.supportedAttributes = .init(rawValue: stat.st_attributes_mask)

        // TODO: on older linux kernels, try to use ioctl with FS_IOC_GETFLAGS to get file attributes

    }

#endif

}
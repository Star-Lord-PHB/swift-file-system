import SystemPackage
import FileSystemCore


extension FileSystem {

    public func info(ofItemAt path: FilePath, followSymlinks: Bool = true) throws(PlatformError) -> FileInfo {
        return try .init(fileAt: path, followSymLink: followSymlinks)
    }


    public func setTimes(
        forItemAt path: FilePath, 
        accessTime: FileTimeSpec? = nil, 
        modificationTime: FileTimeSpec? = nil, 
        creationTime: FileTimeSpec? = nil,
        followSymlink: Bool = true
    ) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileTimes(
                forItemAt: path, 
                access: accessTime, 
                modification: modificationTime,
                creation: creationTime,
                followSymlink: followSymlink
            )
        }
    }


    public func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool = true) throws(PlatformError) {

        #if canImport(Glibc) || canImport(Musl)
        try self.setInodeFlags(forItemAt: path, flags: InternalFS.fileAttributesToInodeFlags(attributes), followSymlink: followSymlink)
        #else
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileAttributes(forItemAt: path, attributes: attributes, followSymlink: followSymlink)
        }
        #endif 

    }


    #if canImport(Glibc) || canImport(Musl)
    public func getInodeFlags(forItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) -> LinuxInodeFlags {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.readFileInodeFlags(forItemAt: path, followSymlink: followSymlink)
        }
    }


    public func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool = true) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags, followSymlink: followSymlink)
        }
    }
    #endif

}
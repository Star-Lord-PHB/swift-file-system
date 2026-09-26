import SystemPackage
import FileSystemCore


extension FileSystem {

    public func info(ofItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) -> FileInfo {
        return try .init(fileAt: path, followSymlink: followSymlink)
    }


    public func setTimes(
        forItemAt path: FilePath, 
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil, 
        creation: FileTimeSpec? = nil,
        followSymlink: Bool = true
    ) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try InternalFS.setTimes(
                forItemAt: path, 
                access: access, 
                modification: modification,
                creation: creation,
                followSymlink: followSymlink
            )
        }
    }


    public func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool = true) throws(PlatformError) {

        #if os(Linux) || os(Android)
        try self.setInodeFlags(forItemAt: path, flags: InternalFS.attributesToInodeFlags(attributes), followSymlink: followSymlink)
        #else
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try InternalFS.setAttributes(forItemAt: path, attributes: attributes, followSymlink: followSymlink)
        }
        #endif 

    }


    #if os(Linux) || os(Android)
    public func getInodeFlags(forItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) -> LinuxInodeFlags {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.readInodeFlags(forItemAt: path, followSymlink: followSymlink)
        }
    }


    public func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool = true) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try InternalFS.setInodeFlags(forItemAt: path, flags: flags, followSymlink: followSymlink)
        }
    }
    #endif

}

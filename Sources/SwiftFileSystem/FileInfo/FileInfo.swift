import FileSystemCore



extension FileInfo {

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(PlatformError) {
        self = try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.getFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
    }

}
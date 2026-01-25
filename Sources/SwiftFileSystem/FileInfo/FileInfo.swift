import FileSystemCore



extension FileInfo {

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(PlatformError) {
        self = try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.getFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
    }

}
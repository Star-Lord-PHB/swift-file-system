import FileSystemCore



extension FileInfo {

    /// Gets the metadata for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to get the metadata for.
    ///   - followSymlink: Whether to follow symbolic links. 
    ///                    If false, the metadata of the symbolic link itself will be retrieved.
    public init(forItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) {
        self = try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.getInfo(forItemAt: path, followSymlink: followSymlink)
        }
    }

}

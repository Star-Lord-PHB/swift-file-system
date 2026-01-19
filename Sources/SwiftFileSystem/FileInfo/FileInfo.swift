import FileSystemCore



extension FileInfo {

    public init(fileAt path: FilePath, followSymLink: Bool = true) throws(FileError) {
        self = try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try InternalFS.getFileInfo(forItemAt: path, followSymlink: followSymLink)
        }
    }

}
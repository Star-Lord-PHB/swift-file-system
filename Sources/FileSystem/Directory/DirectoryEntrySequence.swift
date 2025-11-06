import SystemPackage



public struct DirectoryEntrySequence: DirectoryEntrySequenceProtocol, ~Copyable {

    private let handle: UnsafeSystemHandle
    public let path: FilePath
    public let recursive: Bool


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath, recursive: Bool) {
        self.handle = unsafeSystemHandle
        self.path = path
        self.recursive = recursive
    }


    init(dirAt path: FilePath, recursive: Bool = false) throws(FileError) {
        let handle = try catchSystemError(operationDescription: .openingHandle(forFileAt: path)) { () throws(SystemError) in
            try UnsafeSystemHandle.openDir(at: path)
        }
        self.init(
            unsafeSystemHandle: handle, 
            path: path, 
            recursive: recursive
        )
    }


    public func makeIterator() -> Iterator {
        do {
            if recursive {
                return try DirectoryEntryIterator.recursive(path: path)
            } else {
                return try DirectoryEntryIterator.direct(unsafeSystemHandle: handle, path: path)
            }
        } catch {
            return DirectoryEntryIterator.openError(error: error)
        }
    }

}
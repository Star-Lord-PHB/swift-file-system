import SystemPackage
import FileSystemCore



public struct DirectoryEntrySequence: DirectoryEntrySequenceProtocol, ~Copyable {

    private let handle: UnsafeSystemHandle
    public let path: FilePath
    public let recursive: Bool


    public init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath, recursive: Bool) {
        self.handle = unsafeSystemHandle
        self.path = path
        self.recursive = recursive
    }


    public init(dirAt path: FilePath, recursive: Bool = false) throws(FileError) {
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
                let duplicatedHandle = try catchSystemError(
                    operationDescription: .openingDirStream(forDirectoryAt: path)
                ) { () throws(SystemError) in
                    try handle.duplicate()
                }
                return try DirectoryEntryIterator.direct(unsafeSystemHandle: duplicatedHandle, path: path)
            }
        } catch {
            return DirectoryEntryIterator.openError(error: error)
        }
    }

}
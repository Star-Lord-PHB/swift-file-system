import SystemPackage
import FileSystemCore



public struct DirectoryHandle: ~Copyable, DirectoryHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension DirectoryHandle {

    public init(forDirAt path: FilePath, options: FileOperationOptions.OpenForDirectory = .init()) throws(PlatformError) { 

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: options.unsafeSystemFileOpenOptions()
            )
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    public func directEntries() throws(PlatformError) -> [DirectoryEntry] {
        try ScopedEntrySequence(unsafeSystemHandle: handle, path: path, recursive: false)
            .compactMap { entry throws(PlatformError) in
                switch entry {
                    case .success(.entry(let dirEntry)):    return dirEntry
                    case .success(.entryError):             return nil
                    case .failure(let error):               throw error
                }
            }
    }


    @_lifetime(borrow self)
    public func entrySequence(recursive: Bool = false) throws(PlatformError) -> DirectoryEntrySequenceType {
        return ScopedEntrySequence(unsafeSystemHandle: handle, path: path, recursive: recursive)
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(systemError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension DirectoryHandle {

    public struct ScopedEntrySequence: DirectoryEntrySequenceProtocol, ~Escapable, ~Copyable {

        private let handle: UnsafeUnownedSystemHandle
        public let path: FilePath
        public let recursive: Bool


        @_lifetime(borrow unsafeSystemHandle)
        init(unsafeSystemHandle: borrowing UnsafeSystemHandle, path: FilePath, recursive: Bool) {
            self.handle = unsafeSystemHandle.unownedHandle()
            self.path = path
            self.recursive = recursive
        }


        public func makeIterator() -> Iterator {
            do {
                if recursive {
                    return try DirectoryEntryIterator.recursive(path: path)
                } else {
                    let duplicatedHandle = try catchSystemError(operation: .readDirectory(path)) { () throws(SystemError) in
                        try handle.duplicate()
                    }
                    return try DirectoryEntryIterator.direct(unsafeSystemHandle: duplicatedHandle, path: path)
                }
            } catch {
                return DirectoryEntryIterator.openError(error: error)
            }
        }

    }

}
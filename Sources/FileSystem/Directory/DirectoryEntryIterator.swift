import SystemPackage



public enum DirectoryEntryIterator: DirectoryEntryIteratorProtocol, ~Copyable {

    case direct(DirectoryEntryDirectIterator)
    case recursive(DirectoryEntryRecursiveIterator)
    case openError(DirectoryEntryErrorIterator)


    static func direct(
        unsafeUnownedSystemHandle: UnsafeUnownedSystemHandle, 
        path: FilePath
    ) throws(FileError) -> DirectoryEntryIterator {
        try .direct(.init(unsafeUnownedSystemHandle: unsafeUnownedSystemHandle, path: path))
    }


    static func direct(
        unsafeSystemHandle: borrowing UnsafeSystemHandle, 
        path: FilePath
    ) throws(FileError) -> DirectoryEntryIterator {
        try .direct(.init(unsafeSystemHandle: unsafeSystemHandle, path: path))
    }


    static func recursive(path: FilePath) throws(FileError) -> DirectoryEntryIterator {
        try .recursive(.init(path: path))
    }


    static func openError(error: FileError) -> DirectoryEntryIterator {
        .openError(.init(error: error))
    }


    public mutating func next() -> Result<DirectoryEntry, FileError>? {
        switch consume self {
            case .direct(var iterator):
                let result = iterator.next()
                self = .direct(iterator)
                return result
            case .recursive(var iterator):
                let result = iterator.next()
                self = .recursive(iterator)
                return result
            case .openError(var iterator):
                let result = iterator.next()
                self = .openError(iterator)
                return result
        }
    }

}
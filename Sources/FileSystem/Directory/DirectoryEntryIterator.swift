import SystemPackage



public enum DirectoryEntryIterator: DirectoryEntryIteratorProtocol, ~Copyable {

    case direct(DirectoryEntryDirectIterator)
    case recursive(DirectoryEntryRecursiveIterator)
    case openError(DirectoryEntryErrorIterator)


    static func direct(
        unsafeSystemHandle: consuming UnsafeSystemHandle, 
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


    public mutating func next() -> DirectoryEntrySequenceResult? {
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
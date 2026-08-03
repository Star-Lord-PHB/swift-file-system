import SystemPackage
import FileSystemCore



public struct DirectoryEntryDirectSequence: DirectoryEntryDirectSequenceProtocol, ~Copyable {

    private let handle: UnsafeSystemHandle
    public let path: FilePath
    public let options: FileOperationOptions.DirectoryTraversalOption

    public init(
        unsafeSystemHandle: consuming UnsafeSystemHandle, 
        path: FilePath, 
        options: FileOperationOptions.DirectoryTraversalOption = []
    ) {
        self.handle = unsafeSystemHandle
        self.path = path
        self.options = options
    }

    public init(dirAt path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) throws(PlatformError) {
        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.openDir(at: path)
        }
        // `FILE_FLAG_BACKUP_SEMANTICS` also allows opening regular files, so verify the object type
        // here (POSIX rejects non-directories natively via `O_DIRECTORY`).
        #if canImport(WinSDK)
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            if try handle.type() != .directory {
                throw .init(kind: .notADirectory)
            }
        }
        #endif
        self.init(
            unsafeSystemHandle: handle,
            path: path,
            options: options
        )
    }

    public func makeIterator() -> Iterator {
        return _overrideLifetime(
            DirectoryEntryDirectIterator(unsafeSystemHandle: handle.unownedHandle(), path: path, options: options), 
            borrowing: self
        )
    }

}



public struct DirectoryEntryRecursiveSequence: DirectoryEntryRecursiveSequenceProtocol, ~Copyable {

    public let path: FilePath
    public let options: FileOperationOptions.DirectoryTraversalOption


    public init(dirAt path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
        self.path = path
        self.options = options
    }


    public func makeIterator() -> Iterator {
        return _overrideLifetime(
            DirectoryEntryRecursiveIterator(path: path, options: options), 
            borrowing: self
        )
    }

}
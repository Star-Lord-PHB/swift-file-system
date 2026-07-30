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

        let systemOpenOptions = UnsafeSystemHandle.OpenOptions(
            access: .readOnly(), 
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec, 
            platformSpecificOptions: [.posix.directoryOnly, .windows.backupSemantics]
        )

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(at: path, openOptions: systemOpenOptions)
        }

        #if canImport(WinSDK)
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            if try handle.type() != .directory {
                throw .init(kind: .notADirectory)
            }
        }
        #endif

        self.init(unsafeSystemHandle: handle, path: path)

    }


    public func directEntries(options: FileOperationOptions.DirectoryTraversalOption = []) throws(PlatformError) -> [DirectoryEntry] {
        try ScopedEntryDirectSequence(unsafeSystemHandle: handle, path: path, options: options)
            .map { entry throws(PlatformError) in
                try entry.get()
            }
    }


    @_lifetime(borrow self)
    public func entryDirectSequence(options: FileOperationOptions.DirectoryTraversalOption = []) -> DirectoryEntryDirectSequenceType {
        return ScopedEntryDirectSequence(unsafeSystemHandle: handle, path: path, options: options)
    }


    @_lifetime(borrow self)
    public func entryRecursiveSequence(options: FileOperationOptions.DirectoryTraversalOption = []) -> DirectoryEntryRecursiveSequenceType {
        return ScopedEntryRecursiveSequence(path: path, options: options)
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension DirectoryHandle {

    public struct ScopedEntryDirectSequence: DirectoryEntryDirectSequenceProtocol, ~Escapable, ~Copyable {

        private let handle: UnsafeUnownedSystemHandle
        public let path: FilePath
        public let options: FileOperationOptions.DirectoryTraversalOption


        @_lifetime(borrow unsafeSystemHandle)
        init(
            unsafeSystemHandle: borrowing UnsafeSystemHandle, 
            path: FilePath, 
            options: FileOperationOptions.DirectoryTraversalOption = []
        ) {
            self.handle = unsafeSystemHandle.unownedHandle()
            self.path = path
            self.options = options
        }


        @_lifetime(borrow self)
        public func makeIterator() -> Iterator {
            return _overrideLifetime(
                DirectoryEntryDirectIterator(unsafeSystemHandle: handle, path: path, options: options), 
                copying: self
            )
        }

    }

    public struct ScopedEntryRecursiveSequence: DirectoryEntryRecursiveSequenceProtocol, ~Escapable, ~Copyable {

        public let path: FilePath
        public let options: FileOperationOptions.DirectoryTraversalOption


        @_lifetime(immortal)
        init(path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
            self.path = path
            self.options = options
        }


        @_lifetime(borrow self)
        public func makeIterator() -> Iterator {
            return _overrideLifetime(
                DirectoryEntryRecursiveIterator(path: path, options: options), 
                copying: self
            )
        }

    }

}

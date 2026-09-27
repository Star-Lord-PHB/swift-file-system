import SystemPackage
import FileSystemCore



/// A file handle representing a directory.
public struct DirectoryHandle: ~Copyable, @unchecked Sendable, DirectoryHandleProtocol, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension DirectoryHandle {

    /// Opens a handle for the directory at the specified path.
    /// - Parameters:
    ///   - path: The path of the directory to open.
    ///   - options: The options for opening the directory handle.
    public init(forDirAt path: FilePath, options: FileOperationOptions.OpenForDirectory = .init()) throws(PlatformError) { 

        let systemOpenOptions = UnsafeSystemHandle.OpenOptions(
            access: .readOnly, 
            followSymlink: !options.noFollow, 
            closeOnExec: options.closeOnExec, 
            platformOpenFlagsDiff: .inserted([.posix.directory, .windows.backupSemantics])
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

        self.init(
            unsafeHandleContext: .init(handle: handle, openOptions: systemOpenOptions),
            path: path,
        )

    }


    public func entries(options: FileOperationOptions.DirectoryTraversalOption = []) throws(PlatformError) -> [DirectoryEntry] {
        var iterator = self.entrySequence(options: options).makeIterator()
        var results = [DirectoryEntry]()
        while let entryResult = try iterator.next() {
            results.append(entryResult)
        }
        return results
    }


    /// Returns a sequence for enumerating the direct entries of the directory.
    @_lifetime(borrow self)
    public func entrySequence(options: FileOperationOptions.DirectoryTraversalOption = []) -> EntrySequence {
        return .init(unsafeSystemHandle: context.systemHandle, path: path, options: options)
    }


    package consuming func takeUnsafeHandleContext() -> UnsafeHandleContext {
        self.context
    }


    /// Closes the file handle, releases resources and ends the lifetime.
    public consuming func close() throws(PlatformError) {
        do {
            try context.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get { context.view }
    }

}



extension DirectoryHandle {

    /// A sequence for enumerating the direct entries of a directory.
    public struct EntrySequence: ~Escapable, ~Copyable {

        public typealias Element = DirectoryEntry

        private let handle: UnsafeUnownedSystemHandle
        /// The path of the directory being enumerated.
        public let path: FilePath
        /// The options for enumerating the directory entries.
        public let options: FileOperationOptions.DirectoryTraversalOption


        @_lifetime(borrow unsafeSystemHandle)
        package init(
            unsafeSystemHandle: borrowing UnsafeSystemHandle, 
            path: FilePath, 
            options: FileOperationOptions.DirectoryTraversalOption = []
        ) {
            self.handle = unsafeSystemHandle.unownedHandle()
            self.path = path
            self.options = options
        }


        @_lifetime(copy self)
        public func makeIterator() -> EntryIterator {
            return .init(unsafeSystemHandle: handle, path: path, options: options)
        }

    }


    /// An iterator for enumerating the direct entries of a directory.
    public struct EntryIterator: ~Escapable, ~Copyable {

        private enum State: ~Copyable, ~Escapable {

            case ready(UnsafeUnownedSystemHandle, FilePath, FileOperationOptions.DirectoryTraversalOption)
            case opened(DirectoryEntryDirectEnumerator)
            case ended(FilePath)

            mutating func next() throws(LowLevelError) -> DirectoryEntry? {
                switch consume self {
                    case .ready(let handle, let path, let options):
                        do throws(LowLevelError) {
                            self = .opened(try .init(unsafeSystemHandle: handle.reOpenForDir(), path: path, options: options))
                        } catch {
                            self = .ended(path)
                            throw error
                        }
                    case let s: 
                        self = s
                }
                switch consume self {
                    case .opened(var enumerator):
                        do {
                            let entry = try enumerator.next()
                            self = .opened(enumerator)
                            return entry
                        } catch {
                            self = .opened(enumerator)
                            throw error
                        }
                    case .ended(let path):
                        self = .ended(path)
                        return nil
                    default: 
                        fatalError("Should not reach here")
                }
            }

        }

        private var state: State


        /// The path of the directory being enumerated.
        public var rootPath: FilePath {
            switch state {
                case .ready(_, let path, _): path
                case .opened(let stream): stream.rootPath
                case .ended(let path): path
            }
        }

        /// Whether the enumeration has ended.
        public var ended: Bool {
            switch state {
                case .ready:         false
                case .opened(let e): e.ended
                case .ended:         true

            }
        }


        @_lifetime(copy unsafeSystemHandle)
        package init(
            unsafeSystemHandle: UnsafeUnownedSystemHandle, 
            path: FilePath, 
            options: FileOperationOptions.DirectoryTraversalOption = []
        ) {
            self.state = .ready(unsafeSystemHandle, path, options)
        }


        /// Emit the next entry.
        public mutating func next() throws(PlatformError) -> EntrySequence.Element? {
            return try catchLowLevelError(operation: .readDirectory(rootPath)) { () throws(LowLevelError) in
                try state.next()
            }
        }

    }

}



extension DirectoryHandle.EntrySequence {

    public func forEach<E: Error>(_ body: (Element) throws(E) -> Void) throws {

        var iterator = makeIterator()
        while let entryResult = try iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (Element) throws(E) -> T) throws -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (Element) throws(E) -> T?) throws -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            if let transformed = try transform(entryResult) {
                results.append(transformed)
            }
        }

        return results

    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, Element) throws(E) -> T
    ) throws -> T {

        var result = initialResult
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            result = try nextPartialResult(result, entryResult)
        }

        return result

    }


    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: inout T, 
        _ nextPartialResult: (inout T, Element) throws(E) -> Void
    ) throws {

        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}

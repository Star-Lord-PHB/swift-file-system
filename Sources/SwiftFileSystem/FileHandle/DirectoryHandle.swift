import struct SystemPackage.FilePath
import FileSystemCore



public struct DirectoryHandle: ~Copyable, @unchecked Sendable, DirectoryHandleProtocol, SystemHandleSupportedFileHandleProtocol {

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

        self.init(unsafeSystemHandle: handle, path: path)

    }


    public func entries(options: FileOperationOptions.DirectoryTraversalOption = []) throws(PlatformError) -> [DirectoryEntry] {
        try EntrySequence(unsafeSystemHandle: handle, path: path, options: options)
            .map { entry throws(PlatformError) in
                try entry.get()
            }
    }


    @_lifetime(borrow self)
    public func entrySequence(options: FileOperationOptions.DirectoryTraversalOption = []) -> EntrySequence {
        return .init(unsafeSystemHandle: handle, path: path, options: options)
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    package consuming func takeUnsafeSystemHandle() -> UnsafeSystemHandle {
        self.handle
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension DirectoryHandle {

    public struct EntrySequence: ~Escapable, ~Copyable {

        public typealias Element = Result<DirectoryEntry, PlatformError>

        private let handle: UnsafeUnownedSystemHandle
        public let path: FilePath
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


        @_lifetime(borrow self)
        public func makeIterator() -> EntryIterator {
            return _overrideLifetime(
                .init(unsafeSystemHandle: handle, path: path, options: options), 
                copying: self
            )
        }

    }


    public struct EntryIterator: ~Escapable, ~Copyable {

        private enum State: ~Copyable, ~Escapable {

            case ready(UnsafeUnownedSystemHandle, FilePath, FileOperationOptions.DirectoryTraversalOption)
            case opened(DirectoryEntryDirectEnumerator)
            case ended(FilePath)

            mutating func next() throws(LowLevelError) -> DirectoryEntry? {
                switch consume self {
                    case .ready(let handle, let path, let options):
                        #if canImport(WinSDK)
                        self = .opened(.init(path: path, options: options))
                        #else
                        do throws(LowLevelError) {
                            let newHandle = openat(handle.unsafeRawHandle, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
                            guard newHandle >= 0 else {
                                try LowLevelError.assertError()
                            }
                            self = .opened(try .init(unsafeSystemHandle: .init(owningRawHandle: newHandle), path: path, options: options))
                        } catch {
                            self = .ended(path)
                            throw error
                        }
                        #endif
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


        public var rootPath: FilePath {
            switch state {
                case .ready(_, let path, _): path
                case .opened(let stream): stream.rootPath
                case .ended(let path): path
            }
        }

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


        public mutating func next() -> EntrySequence.Element? {
            do {
                return try state.next().map { .success($0) }
            } catch {
                return .failure(.init(lowLevelError: error, operation: .readDirectory(rootPath)))
            }
        }

    }

}



extension DirectoryHandle.EntrySequence {

    public func forEach<E: Error>(_ body: (Element) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (Element) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (Element) throws(E) -> T?) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            if let transformed = try transform(entryResult) {
                results.append(transformed)
            }
        }

        return results

    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, Element) throws(E) -> T
    ) throws(E) -> T {

        var result = initialResult
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            result = try nextPartialResult(result, entryResult)
        }

        return result

    }


    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: inout T, 
        _ nextPartialResult: (inout T, Element) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}

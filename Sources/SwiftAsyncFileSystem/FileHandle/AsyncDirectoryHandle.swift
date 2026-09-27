import SystemPackage
private import struct DequeModule.Deque
import SwiftFileSystem



/// A file handle representing a directory.
public struct AsyncDirectoryHandle
: ~Copyable, @unchecked Sendable
, AsyncDirectoryHandleProtocol, AutoSynthesisAsyncFileHandleProtocol {

    let context: UnsafeHandleContext
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    /// Opens a handle for the directory at the specified path.
    /// - Parameters:
    ///   - path: The path of the directory to open.
    ///   - options: The options for opening the directory handle.
    ///   - executor: The executor for executing the IO operations
    @concurrent
    public init(
        forDirAt path: FilePath, 
        options: FileOperationOptions.OpenForDirectory = .init(), 
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try DirectoryHandle(forDirAt: path, options: options)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeHandleContext()
        self.path = path
        self.executor = executor
    }


    /// Closes the file handle, releases resources and ends the lifetime.
    /// 
    /// - Note: This method is not cancellable.
    @concurrent
    public consuming func close() async throws(PlatformError) {
        let executor = self.executor
        let path = self.path
        var context = Optional.some(self.context)
        return try await executor.run { () throws(PlatformError) in
            try catchLowLevelError(operation: .closeHandle(originalPath: path)) { () throws(LowLevelError) in
                let handle = context.take()!
                try handle.close()
            }
        }
    }


    public var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get { context.view }
    }


    @concurrent
    public func entries(options: FileOperationOptions.DirectoryTraversalOption = []) async throws(PlatformError) -> [DirectoryEntry] {
        var iterator = self.entrySequence(options: options).makeAsyncIterator()
        var results = [DirectoryEntry]()
        while let entryResult = try await iterator.next() {
            results.append(entryResult)
        }
        return results
    }


    /// Returns a sequence for enumerating the direct entries of the directory.
    @_lifetime(borrow self)
    public func entrySequence(
        options: FileOperationOptions.DirectoryTraversalOption = [], 
        batchCount: Int = AsyncEntrySequence.defaultBatchCount
    ) -> AsyncEntrySequence {
        return .init(
            syncSequence: .init(unsafeSystemHandle: context.systemHandle, path: path, options: options), 
            batchCount: batchCount, 
            executor: executor
        )
    }

}



extension AsyncDirectoryHandle {

    /// A sequence for enumerating the direct entries of a directory.
    public struct AsyncEntrySequence: ~Copyable, ~Escapable {

        public typealias Element = DirectoryEntry

        /// The default number of entries to fetch in a single batch
        public static var defaultBatchCount: Int { 128 }

        private let syncSequence: DirectoryHandle.EntrySequence
        /// The number of entries to fetch in a single batch
        public let batchCount: Int
        /// The executor for executing the IO operations
        public let executor: AsyncFileSystemExecutor

        /// The path of the directory being enumerated.
        public var path: FilePath { syncSequence.path }
        /// The options for enumerating the directory entries.
        public var options: FileOperationOptions.DirectoryTraversalOption { syncSequence.options }


        @_lifetime(copy syncSequence)
        init(
            syncSequence: consuming DirectoryHandle.EntrySequence,
            batchCount: Int = defaultBatchCount,
            executor: AsyncFileSystemExecutor = .defaultExecutor
        ) {
            precondition(batchCount > 0, "Batch count must be greater than 0")
            self.syncSequence = syncSequence
            self.batchCount = batchCount
            self.executor = executor
        }


        @_lifetime(copy self)
        public func makeAsyncIterator() -> AsyncEntryIterator {
            return .init(
                syncIterator: syncSequence.makeIterator(),
                batchCount: batchCount,
                executor: executor
            )
        }

    }



    /// An iterator for enumerating the direct entries of a directory.
    public struct AsyncEntryIterator: ~Copyable, ~Escapable {

        var syncIterator: DirectoryHandle.EntryIterator
        /// The executor for executing the IO operations
        public let executor: AsyncFileSystemExecutor

        private var batch: Deque<AsyncEntrySequence.Element> = .init()
        private var pendingErr: PlatformError?
        /// The number of entries to fetch in a single batch
        public let batchCount: Int

        /// The path of the directory being enumerated.
        public var rootPath: FilePath { syncIterator.rootPath }
        /// Whether the enumeration has ended.
        public var ended: Bool { syncIterator.ended && batch.isEmpty && pendingErr == nil }


        @_lifetime(copy syncIterator)
        package init(
            syncIterator: consuming DirectoryHandle.EntryIterator, 
            batchCount: Int = AsyncEntrySequence.defaultBatchCount,
            executor: AsyncFileSystemExecutor = .defaultExecutor
        ) {
            self.executor = executor
            self.batchCount = batchCount
            self.syncIterator = syncIterator
            batch.reserveCapacity(batchCount)
        }


        /// Emit the next entry.
        @concurrent
        public mutating func next() async throws(PlatformError) -> AsyncEntrySequence.Element? {

            if Task.isCancelled {
                throw .taskCancelled(operation: .readDirectory(rootPath))
            }

            if let entry = batch.popFirst() {
                return entry
            }

            if let pendingErr = pendingErr.take() { throw pendingErr }

            try await executor.runCancellable {
                do throws(PlatformError) {
                    for _ in 0 ..< batchCount {
                        guard let entry = try syncIterator.next() else { return }
                        batch.append(entry)
                    }
                } catch {
                    pendingErr = error
                    return
                }
            }
            .get(mappingCancellation: PlatformError.taskCancelled(operation: .readDirectory(rootPath)))

            if let entry = batch.popFirst() {
                return entry
            } else if let pendingErr = pendingErr.take() {
                throw pendingErr
            } else {
                return nil
            }

        }

    }

}



extension AsyncDirectoryHandle.AsyncEntrySequence {

    @concurrent
    public func forEach<E: Error>(_ body: @concurrent (Element) async throws(E) -> Void) async throws {

        var iterator = makeAsyncIterator()
        while let entryResult = try await iterator.next() {
            try await body(entryResult)
        }

    }


    @concurrent
    public func map<T, E: Error>(_ transform: @concurrent (Element) async throws(E) -> T) async throws -> [T] {

        var results = [T]()
        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            results.append(try await transform(entryResult))
        }

        return results

    }


    @concurrent
    public func compactMap<T, E: Error>(_ transform: @concurrent (Element) async throws(E) -> T?) async throws -> [T] {

        var results = [T]()
        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            if let transformed = try await transform(entryResult) {
                results.append(transformed)
            }
        }

        return results

    }


    @concurrent
    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: @concurrent (consuming T, Element) async throws(E) -> T
    ) async throws -> T {

        var result = initialResult
        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            result = try await nextPartialResult(result, entryResult)
        }

        return result

    }


    @concurrent
    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: inout T, 
        _ nextPartialResult: @concurrent (inout T, Element) async throws(E) -> Void
    ) async throws {

        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            try await nextPartialResult(&initialResult, entryResult)
        }

    }

}

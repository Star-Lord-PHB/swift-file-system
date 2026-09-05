import struct SystemPackage.FilePath
import struct SwiftFileSystem.DirectoryHandle
private import struct DequeModule.Deque



public struct AsyncDirectoryHandle
: ~Copyable, @unchecked Sendable
, AsyncDirectoryHandleProtocol, AutoSynthesisAsyncFileHandleProtocol {

    let handle: UnsafeSystemHandle
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    public init(
        forDirAt path: FilePath, 
        options: FileOperationOptions.OpenForDirectory = .init(), 
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.handle = try await executor.runCancellable { () throws(PlatformError) in
            try DirectoryHandle(forDirAt: path, options: options)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeSystemHandle()
        self.path = path
        self.executor = executor
    }


    @concurrent
    public consuming func close() async throws(PlatformError) {
        let executor = self.executor
        let path = self.path
        var handle = Optional.some(self.handle)
        return try await executor.run { () throws(PlatformError) in
            try catchLowLevelError(operation: .closeHandle(originalPath: path)) { () throws(LowLevelError) in
                let handle = handle.take()!
                try handle.close()
            }
        }
    }


    @concurrent
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R {
        try await operation(handle)
    }


    @concurrent
    public func entries(options: FileOperationOptions.DirectoryTraversalOption = []) async throws(PlatformError) -> [DirectoryEntry] {
        let sequence = self.entrySequence(options: options)
        var iterator = sequence.makeAsyncIterator()
        var results = [DirectoryEntry]()
        while let entryResult = try await iterator.next() {
            results.append(entryResult)
        }
        return results
    }


    @_lifetime(borrow self)
    public func entrySequence(
        options: FileOperationOptions.DirectoryTraversalOption = [], 
        batchCount: Int = AsyncEntrySequence.defaultBatchCount
    ) -> AsyncEntrySequence {
        return .init(
            syncSequence: .init(unsafeSystemHandle: handle, path: path, options: options), 
            batchCount: batchCount, 
            executor: executor
        )
    }

}



extension AsyncDirectoryHandle {

    public struct AsyncEntrySequence: ~Copyable, ~Escapable {

        public typealias Element = DirectoryEntry

        public static var defaultBatchCount: Int { 128 }

        private let syncSequence: DirectoryHandle.EntrySequence
        public let batchCount: Int
        public let executor: AsyncFileSystemExecutor


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


        @_lifetime(borrow self)
        public func makeAsyncIterator() -> AsyncEntryIterator {
            return .init(
                syncIterator: syncSequence.makeIterator(),
                batchCount: batchCount,
                executor: executor
            )
        }

    }



    public struct AsyncEntryIterator: ~Copyable, ~Escapable {

        var syncIterator: DirectoryHandle.EntryIterator
        public let executor: AsyncFileSystemExecutor

        private var batch: Deque<AsyncEntrySequence.Element> = .init()
        private var pendingErr: PlatformError?
        public let batchCount: Int

        public var rootPath: FilePath { syncIterator.rootPath }
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
                for _ in 0 ..< batchCount {
                    switch syncIterator.next() {
                        case .none: 
                            return
                        case .failure(let err):
                            pendingErr = err
                            return
                        case .success(let entry):
                            batch.append(entry)
                    }
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

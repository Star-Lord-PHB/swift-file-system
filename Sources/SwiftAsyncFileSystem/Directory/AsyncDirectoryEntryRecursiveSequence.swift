import struct SystemPackage.FilePath
import struct SwiftFileSystem.DirectoryEntryRecursiveSequence
private import struct DequeModule.Deque
import enum SwiftFileSystem.DirectoryEntryRecursiveSequenceElement



public struct AsyncDirectoryEntryRecursiveSequence: Sendable {

    public typealias Element = SwiftFileSystem.DirectoryEntryRecursiveSequenceElement

    public static var defaultBatchCount: Int { 128 }

    let syncSequence: DirectoryEntryRecursiveSequence
    public let batchCount: Int
    public let executor: AsyncFileSystemExecutor

    public var path: FilePath { syncSequence.path }
    public var options: FileOperationOptions.DirectoryTraversalOption { syncSequence.options }


    public init(
        dirAt path: FilePath, 
        options: FileOperationOptions.DirectoryTraversalOption = [], 
        batchCount: Int = defaultBatchCount, 
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) {
        precondition(batchCount > 0, "Batch count must be greater than 0")
        self.syncSequence = .init(dirAt: path, options: options)
        self.batchCount = batchCount
        self.executor = executor
    }


    public func makeAsyncIterator() -> AsyncIterator {
        return .init(
            syncIterator: syncSequence.makeIterator(),
            batchCount: batchCount, 
            executor: executor
        )
    }

}



extension AsyncDirectoryEntryRecursiveSequence {

    public struct AsyncIterator: ~Copyable {

        var syncIterator: DirectoryEntryRecursiveSequence.Iterator
        public let executor: AsyncFileSystemExecutor

        private var batch: Deque<DirectoryEntryRecursiveSequenceElement> = .init()
        private var pendingErr: PlatformError?
        public let batchCount: Int

        public var rootPath: FilePath { syncIterator.rootPath }


        package init(
            syncIterator: consuming DirectoryEntryRecursiveSequence.Iterator, 
            batchCount: Int = defaultBatchCount,
            executor: AsyncFileSystemExecutor = .defaultExecutor
        ) {
            self.executor = executor
            self.batchCount = batchCount
            self.syncIterator = syncIterator
            batch.reserveCapacity(batchCount)
        }


        @concurrent
        public mutating func next() async throws(PlatformError) -> DirectoryEntryRecursiveSequenceElement? {

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



extension AsyncDirectoryEntryRecursiveSequence {

    @concurrent
    public func forEach<E: Error>(_ body: @concurrent (DirectoryEntryRecursiveSequenceElement) async throws(E) -> Void) async throws {
        var iterator = makeAsyncIterator()
        while let entryResult = try await iterator.next() {
            try await body(entryResult)
        }
    }


    @concurrent
    public func map<T, E: Error>(_ transform: @concurrent (DirectoryEntryRecursiveSequenceElement) async throws(E) -> T) async throws -> [T] {

        var results = [T]()
        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            results.append(try await transform(entryResult))
        }

        return results

    }


    @concurrent
    public func compactMap<T, E: Error>(_ transform: @concurrent (DirectoryEntryRecursiveSequenceElement) async throws(E) -> T?) async throws -> [T] {

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
        _ nextPartialResult: @concurrent (consuming T, DirectoryEntryRecursiveSequenceElement) async throws(E) -> T
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
        _ nextPartialResult: @concurrent (inout T, DirectoryEntryRecursiveSequenceElement) async throws(E) -> Void
    ) async throws {

        var iterator = makeAsyncIterator()

        while let entryResult = try await iterator.next() {
            try await nextPartialResult(&initialResult, entryResult)
        }

    }

}

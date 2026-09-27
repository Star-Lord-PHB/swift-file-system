import SystemPackage
private import struct DequeModule.Deque
import SwiftFileSystem



/// A sequence for recursively traversing a directory and its subdirectories, yielding 
/// ``DirectoryEntryRecursiveSequenceElement`` values.
public struct AsyncDirectoryEntryRecursiveSequence: Sendable {

    public typealias Element = SwiftFileSystem.DirectoryEntryRecursiveSequenceElement

    /// The default number of entries to fetch in a single batch
    public static var defaultBatchCount: Int { 128 }

    let syncSequence: DirectoryEntryRecursiveSequence
    /// The number of entries to fetch in a single batch
    public let batchCount: Int
    /// The executor for executing the IO operations
    public let executor: AsyncFileSystemExecutor

    /// The path of the directory to traverse.
    public var path: FilePath { syncSequence.path }
    /// The options for directory traversal.
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

    /// The iterator for recursively traversing a directory and its subdirectories.
    public struct AsyncIterator: ~Copyable {

        private enum SkipRequest {
            case none
            case skipDescendants
            case skipCurrentDir
        }

        var syncIterator: DirectoryEntryRecursiveSequence.Iterator
        /// The executor for executing the IO operations
        public let executor: AsyncFileSystemExecutor

        private var batch: Deque<Element> = .init()

        private var prevEmittedElementIsDir: Bool = false
        private var prevEmittedElementPathLength: Int = 0
        private var skipRequest: SkipRequest = .none

        private var pendingErr: PlatformError?
        /// The number of entries to fetch in a single batch
        public let batchCount: Int

        /// The path of the root directory being traversed.
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


        /// Skips the descendants of a newly meet directory.
        /// 
        /// If the current entry that is just emitted is a directory, this method will skip that directory 
        /// without emitting a ``DirectoryEntryRecursiveSequenceElement/leavingDir(_:_:)`` element. Otherwise, this 
        /// method has no effect
        public mutating func skipDescendants() {
            if skipRequest == .none && prevEmittedElementIsDir {
                skipRequest = .skipDescendants
            }
        }


        /// Leaves the current directory early and emits a ``DirectoryEntryRecursiveSequenceElement/leavingDir(_:_:)``
        /// element.
        public mutating func skipCurrentDir() {
            skipRequest = .skipCurrentDir
        }


        /// Emit the next element.
        @concurrent
        public mutating func next() async throws(PlatformError) -> Element? {

            defer { skipRequest = .none }

            if Task.isCancelled {
                throw .taskCancelled(operation: .readDirectory(rootPath))
            }

            var iteratorPopTargetLength = nil as Int?

            if skipRequest == .skipDescendants && batch.isEmpty {

                syncIterator.skipDescendants()

            } else if skipRequest != .none {

                iteratorPopTargetLength = switch skipRequest {
                    case .skipDescendants: prevEmittedElementPathLength
                    case .skipCurrentDir: prevEmittedElementPathLength - 1
                    case .none: fatalError("Unreachable")
                }

                while let element = batch.popFirst() {
                    if element.path.components.count == iteratorPopTargetLength {
                        switch element {
                            case .leavingDir, .subTreeError: break
                            default: assertionFailure("Expected the element closing the skipped region, got \(element)")
                        }
                        if skipRequest == .skipCurrentDir {
                            batch.prepend(.leavingDir(element.path, nil))
                        }
                        iteratorPopTargetLength = nil   // target reached, no need to pop the iterator
                        break
                    }
                }

            }

            precondition(
                (iteratorPopTargetLength != nil && !batch.isEmpty) == false,
                "The batch must be empty if the iterator needs to pop back to some level"
            )

            if let entry = batch.popFirst() {
                recordEmittedElement(entry)
                return entry
            }

            try await executor.runCancellable { () throws(PlatformError) in
                var poppedCount = 0
                if let iteratorPopTargetLength {
                    iteratorPopLoop: while true {
                        poppedCount += 1
                        syncIterator.skipCurrentDir()
                        // here the batch must be empty, so we can throw the error directly without using pendingErr
                        switch try syncIterator.next() {
                            case .none: 
                                return
                            case .entry, .entryError:
                                preconditionFailure("Expected to skip a directory and and should not emit an entry element")
                            case .some(let element) where element.path.components.count == iteratorPopTargetLength:
                                if skipRequest == .skipCurrentDir {
                                    batch.append(element)
                                }
                                break iteratorPopLoop
                            case .leavingDir, .subTreeError:
                                continue
                        }
                    }
                }
                do throws(PlatformError) {
                    for _ in 0 ..< max(batchCount - poppedCount, 1) {
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
                recordEmittedElement(entry)
                return entry
            } else if skipRequest == .skipCurrentDir {
                // Here the root dir is being skipped, previous pending error is ignored due to early exit
                pendingErr = nil
                return nil
            } else if let pendingErr = pendingErr.take() {
                throw pendingErr
            } else {
                return nil
            }

        }


        private mutating func recordEmittedElement(_ element: Element) {
            prevEmittedElementIsDir = switch element {
                case .entry(let entry): entry.type == .directory && entry.path.lastComponent?.kind == .regular
                default: false
            }
            prevEmittedElementPathLength = element.path.components.count
        }

    }

}



extension AsyncDirectoryEntryRecursiveSequence {

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

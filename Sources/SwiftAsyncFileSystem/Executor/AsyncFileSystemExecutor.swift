//
//  AsyncFileSystemExecutor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//

private import struct DequeModule.UniqueDeque
import struct FileSystemCore.PlatformError
import class FileSystemCore.CancellationToken


/// An elastic thread-pool-based executor for executing IO operations asynchronously.
public final class AsyncFileSystemExecutor: Sendable {
    
    /// A type representing a task submitted into the executor, guaranteed to be executed at most once.
    public struct CalledOnceExecutorTask: ~Copyable {
        private let task: () -> Void
        public init(_ task: consuming sending @escaping () -> Void) { self.task = task }
        public consuming func callAsFunction() { task() }
    }
    
    
    /// The state of the executor.
    public enum State: Sendable, Equatable, Hashable {
        case running, stopped
    }
    
    
    fileprivate final class Storage {
        var state: State = .running
        var tasks: UniqueDeque<CalledOnceExecutorTask> = .init()
        var spawnedThreadCount: Int = 0
        var idleThreadCount: Int = 0
        var aliveThreadCount: Int = 0
    }

    
    fileprivate struct LockedCondition: Sendable {
        private unowned let cond: ConditionalVariable
        init(_ cond: ConditionalVariable) { self.cond = cond }
        func wait() {
            cond.wait()
        }
        func wait(until deadline: MonotonicInstant) -> Bool {
            cond.wait(until: deadline)
        }
        func signal() {
            cond.signal()
        }
        func broadcast() {
            cond.broadcast()
        }
    }
    
    
    fileprivate struct AtomicStorage: @unchecked Sendable {
        private let storage: Storage = .init()
        private let cond: ConditionalVariable = .init()
        
        var state: State {
            withLock { storage, _ in
                storage.state
            }
        }
        
        func withLock<R: ~Copyable, E: Error>(
            _ body: (_ storage: Storage, _ cond: LockedCondition) throws(E) -> R
        ) throws(E) -> R {
            try cond.withLock { () throws(E) in
                try body(storage, .init(cond))
            }
        }
    }
    
    
    /// The custom label for the executor, used as the prefix of the thread names if applicable.
    public let label: String
    /// The minimum number of threads kept alive in the executor (number of persistent threads).
    public let minimumThreadCount: Int
    /// The maxinum number of threads allowed in the executor.
    public let maximumThreadCount: Int
    fileprivate let idleTimeout: MonotonicDuration
    fileprivate let storage: AtomicStorage
    
    /// The current state of the executor.
    public var state: State { storage.state }
    /// The idle timeout of the elastic threads in the executor, in nanoseconds.
    /// 
    /// If an elastic thread stays idle for longer than this duration, it will be terminated.
    public var idleTimeoutNano: Int64 { idleTimeout.nanoseconds }

    
    /// Creates an executor with the specified label and number of persistent threads.
    /// - Parameters:
    ///   - label: The custom label for the executor.
    ///   - threadCount: The number of persistent threads in the executor.
    /// 
    /// - Note: Executor created with this initializer will have all threads persistent and no elastic 
    ///         threads. It will not create new threads when all the existing threads are busy, and will not
    ///         terminate any threads when they are idle.
    public convenience init(label: String, threadCount: Int) {
        self.init(
            label: label,
            minimumThreadCount: threadCount,
            maximumThreadCount: threadCount,
            idleTimeout: .init(nanoseconds: .max)
        )
    }


    /// Creates an executor with the specified label, minimum and maximum number of threads, and idle timeout.
    /// - Parameters:
    ///   - label: The custom label for the executor.
    ///   - minimumThreadCount: The minimum number of threads kept alive in the executor (number of persistent threads).
    ///   - maximumThreadCount: The maximum number of threads allowed in the executor.
    ///   - idleTimeout: The idle timeout of the elastic threads in the executor. If an elastic thread stays 
    ///                  idle for longer than this duration, it will be terminated.
    public init(label: String, minimumThreadCount: Int = 0, maximumThreadCount: Int, idleTimeout: MonotonicDuration = .seconds(10)) {

        precondition(maximumThreadCount > 0, "Maximum thread count must be greater than 0")
        precondition(minimumThreadCount <= maximumThreadCount, "Minimum thread count must be less than or equal to maximum thread count")
        precondition(idleTimeout.nanoseconds > 0, "Idle timeout must be greater than 0")

        self.label = label
        self.minimumThreadCount = minimumThreadCount
        self.maximumThreadCount = maximumThreadCount
        self.idleTimeout = idleTimeout

        let atomicStorage = AtomicStorage()
        self.storage = atomicStorage

        self.storage.withLock { storage, _ in
            for i in 0 ..< minimumThreadCount {
                Thread(name: Self.makeThreadName(label: label, id: i)) {
                    Self.persistentThreadTask(atomicStorage)
                }.start()
            }
            storage.aliveThreadCount = minimumThreadCount
            storage.spawnedThreadCount = minimumThreadCount
        }

    }


    deinit {
        storage.withLock { storage, cond in
            storage.state = .stopped
            cond.broadcast()
        }
    }


    fileprivate static func makeThreadName(label: String, id: Int) -> String {
        let idStr = "-\(id)"
        let maxLabelLength = max(15 - idStr.utf8.count, 0)
        return "\(label.prefix(maxLabelLength))\(idStr)"
    }

    
    fileprivate static func persistentThreadTask(_ storage: AtomicStorage) {

        while true {

            let task = storage.withLock { storage, cond in

                while true {

                    if storage.state == .stopped {
                        storage.aliveThreadCount -= 1
                        return nil as CalledOnceExecutorTask?
                    } else if let task = storage.tasks.popFirst() {
                        return task
                    }

                    storage.idleThreadCount += 1
                    cond.wait()
                    storage.idleThreadCount -= 1

                }

            }

            guard let task else { break }

            task()

        }

    }


    fileprivate static func elasticThreadTask(_ storage: AtomicStorage, _ idleTimeout: MonotonicDuration) {

        while true {

            let task = storage.withLock { storage, cond in

                if storage.state == .stopped {
                    storage.aliveThreadCount -= 1
                    return nil as CalledOnceExecutorTask?
                } else if let task = storage.tasks.popFirst() {
                    return task
                }

                let deadline = MonotonicInstant.now() + idleTimeout

                while true {

                    storage.idleThreadCount += 1
                    let signaled = cond.wait(until: deadline)
                    storage.idleThreadCount -= 1

                    if storage.state == .stopped {
                        storage.aliveThreadCount -= 1
                        return nil as CalledOnceExecutorTask?
                    } else if let tasks = storage.tasks.popFirst() {
                        return tasks
                    } else if !signaled {
                        storage.aliveThreadCount -= 1
                        return nil as CalledOnceExecutorTask?
                    }

                }

            }

            guard let task else { break }

            task()

        }

    }
    
    
    /// Submits a new task to the executor, guaranteed to be executed at most once.
    /// - Parameter task: The task to be executed.
    public func submit(_ task: consuming sending CalledOnceExecutorTask) {

        precondition(state == .running, "Cannot submit tasks to an executor that is not running")

        var task = Optional.some(task)

        storage.withLock { storage, cond in

            storage.tasks.append(task.take()!)

            if storage.idleThreadCount == 0 && storage.aliveThreadCount < maximumThreadCount {
                let threadName = Self.makeThreadName(label: label, id: storage.spawnedThreadCount)
                let thread = Thread(name: threadName) { [atomicStorage = self.storage, idleTimeout] in
                    Self.elasticThreadTask(atomicStorage, idleTimeout)
                }
                if thread.startReturningFailure() == nil {
                    storage.aliveThreadCount += 1
                    storage.spawnedThreadCount += 1
                } else if storage.aliveThreadCount == 0 {
                    // Growth being skipped is survivable while workers exist (the queued
                    // task will be drained by one of them), but with no worker at all the
                    // task could wait forever.
                    fatalError("Thread exhaustion left the executor without any worker thread")
                }
            }

            cond.signal()

        }

    }
    
}



extension AsyncFileSystemExecutor {
    
    final class NonCopyableBox<V: ~Copyable> {
        
        nonisolated(unsafe) private var value: V?
        
        init(_ value: consuming sending V) {
            self.value = .some(value)
        }
        
        func take() -> sending V? {
            return value.take()
        }
        
    }


    /// Executes a closure on the executor and waits for the result asynchronously.
    /// - Parameter task: The closure to be executed on the executor.
    @concurrent
    public func run<R: ~Copyable, E: Error>(
        _ task: () throws(E) -> R
    ) async throws(E) -> R {

        return try await withoutActuallyEscaping(task) { (escapingClosure) async throws(E) in

            nonisolated(unsafe) var taskWrapper = escapingClosure as (() throws -> R)?

            do {
                return try await withCheckedThrowingContinuation { continuation in
                    self.submit(.init { @Sendable in
                        do {
                            let task = taskWrapper.take()!
                            let result = try task()
                            _ = consume task
                            continuation.resume(returning: NonCopyableBox(result))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    })
                }
            } catch let error as E {
                throw error
            } catch {
                preconditionFailure()
            }

            fatalError()

        }.take()!

    }


    /// Executes a closure on the executor and waits for the result asynchronously.
    /// - Parameter task: The closure to be executed on the executor.
    public func runSending<R: ~Copyable, E: Error>(
        _ task: sending () throws(E) -> sending R
    ) async throws(E) -> sending R {
        return try await run(task)
    }

}



extension AsyncFileSystemExecutor {

    /// A type representing the execution result of a task submitted into the executor.
    public enum Result<V: ~Copyable, E: Error>: ~Copyable {

        /// The task completed successfully with a return value.
        case success(V)
        /// The task failed with an error.
        case failure(E)
        /// The task was cancelled before it could be executed.
        case cancelled

        /// Gets the return value of the submitted task, or throws if the task failed or was cancelled.
        /// 
        /// * If the task completed successfully, the return value is returned.
        /// * If the task failed with an error, the error is thrown.
        /// * If the task was cancelled, a [`CancellationError`] is thrown.
        /// 
        /// [`CancellationError`]: https://docs.swift.org/latest/documentation/swift/cancellationerror
        public consuming func get() throws -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw CancellationError()
            }
        }

        /// Gets the return value of the submitted task, or throws if the task failed or was cancelled.
        /// - Parameter cancellationMapping: The error to throw if the task was cancelled.
        /// 
        /// * If the task completed successfully, the return value is returned.
        /// * If the task failed with an error, the error is thrown.
        /// * If the task was cancelled, a `cancellationMapping()` is thrown.
        public consuming func get<C: Error>(mappingCancellation cancellationMapping: @autoclosure () -> C) throws -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw cancellationMapping()
            }
        }

        /// Gets the return value of the submitted task, or throws if the task failed or was cancelled.
        /// - Parameter cancellationMapping: The error to throw if the task was cancelled.
        /// 
        /// * If the task completed successfully, the return value is returned.
        /// * If the task failed with an error, the error is thrown.
        /// * If the task was cancelled, a `cancellationMapping()` is thrown.
        public consuming func get(mappingCancellation cancellationMapping: @autoclosure () -> E) throws(E) -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw cancellationMapping()
            }
        }

        /// Gets the return value of the submitted task, or throws if the task was cancelled.
        /// - Parameter cancellationMapping: The error to throw if the task was cancelled.
        /// 
        /// * If the task completed successfully, the return value is returned.
        /// * If the task was cancelled, a `cancellationMapping()` is thrown.
        public consuming func get<C: Error>(mappingCancellation cancellationMapping: @autoclosure () -> C) throws(C) -> V where E == Never {
            switch consume self {
            case .success(let v): return v
            case .failure: preconditionFailure("unreachable")
            case .cancelled: throw cancellationMapping()
            }
        }

        package consuming func getThrowingPlatformError(
            operation: @autoclosure () -> PlatformError.Operation
        ) throws(PlatformError) -> V where E == PlatformError {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw .init(error: CancellationError(), kind: .cancelled, operation: operation())
            }
        }

        
        package consuming func getThrowingPlatformError(
            operation: @autoclosure () -> PlatformError.Operation
        ) throws(PlatformError) -> V where E == LowLevelError {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw .init(lowLevelError: e, operation: operation())
            case .cancelled: throw .init(error: CancellationError(), kind: .cancelled, operation: operation())
            }
        }

        /// Creates a new ``Result`` by mapping its error to a new error type.
        /// - Parameter transform: A closure that transforms the error to a new error type.
        public consuming func mapError<E2: Error>(_ transform: (E) -> E2) -> Result<V, E2> {
            switch consume self {
            case .success(let v): return .success(v)
            case .failure(let e): return .failure(transform(e))
            case .cancelled: return .cancelled
            }
        }

    }

}



extension AsyncFileSystemExecutor.Result: Sendable where V: Sendable {}



extension AsyncFileSystemExecutor {

    /// Executes a cancellable closure on the executor and waits for the result asynchronously.
    /// - Parameter task: The closure to be executed on the executor.
    /// 
    /// Before executing the provided closure, the executor will check if the current Task has been 
    /// cancelled. If so, the closure will be discarded and the result will be ``Result/cancelled``.
    @concurrent
    package func runCancellable<R: ~Copyable, E: Error>(
        _ task: () throws(E) -> R
    ) async -> Result<R, E> {

        guard !Task.isCancelled else {
            return .cancelled
        }

        let token = CancellationToken()

        return await withoutActuallyEscaping(task) { (escapingTask) async in

            nonisolated(unsafe) var taskWrapper = escapingTask as (() throws -> R)?

            typealias ContinuationType = CheckedContinuation<NonCopyableBox<Result<R, E>>, Never>

            return await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: ContinuationType) in
                    self.submit(.init { @Sendable in
                        guard !token.isCancelled else {
                                // Release the unused task reference before resuming: resuming
                                // lets `withoutActuallyEscaping` return, which traps if the
                                // closure is still referenced at that point.
                            taskWrapper = nil
                            continuation.resume(returning: NonCopyableBox(.cancelled))
                            return
                        }
                        do {
                            let task = taskWrapper.take()!
                            let result = try task()
                            _ = consume task
                            continuation.resume(returning: NonCopyableBox(.success(result)))
                        } catch let error as E {
                            continuation.resume(returning: NonCopyableBox(.failure(error)))
                        } catch {
                            preconditionFailure()
                        }
                    })
                }
            } onCancel: {
                token.cancel()
            }

        }.take()!

    }


    /// Executes a cancellable closure on the executor and waits for the result asynchronously.
    /// - Parameter task: The closure to be executed on the executor.
    /// 
    /// Before executing the provided closure, the executor will check if the current Task has been 
    /// cancelled. If so, the closure will be discarded and the result will be ``Result/cancelled``.
    public func runCancellableSending<R: ~Copyable, E: Error>(
        _ task: sending () throws(E) -> sending R
    ) async -> sending Result<R, E> {
        return await runCancellable(task)
    }

}



extension AsyncFileSystemExecutor {

    /// Default ``AsyncFileSystemExecutor/maximumThreadCount`` for ``defaultExecutor``.
    /// 
    /// The value is platform-dependent:
    /// 
    /// | Platform | Value |
    /// | --- | --- |
    /// | watchOS | 8 |
    /// | iOS / tvOS / visionOS | 32 |
    /// | Other platforms | 64 |
    public static let defaultMaximumThreadCount: Int = {
        #if os(watchOS)
        return 8
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        return 32
        #else
        return 64
        #endif
    }()


    /// Shared process-wide executor.
    /// 
    /// | Config | Value |
    /// | --- | --- |
    /// | ``AsyncFileSystemExecutor/label`` | fs-io |
    /// | ``AsyncFileSystemExecutor/minimumThreadCount`` | 0 |
    /// | ``AsyncFileSystemExecutor/maximumThreadCount`` | ``AsyncFileSystemExecutor/defaultMaximumThreadCount`` |
    /// | ``AsyncFileSystemExecutor/idleTimeoutNano`` | 10 milliseconds |
    public static let defaultExecutor: AsyncFileSystemExecutor = .init(
        label: "fs-io",
        maximumThreadCount: defaultMaximumThreadCount
    )

}



@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension AsyncFileSystemExecutor: TaskExecutor {
    
    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        self.submit(.init {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        })
    }
    
}

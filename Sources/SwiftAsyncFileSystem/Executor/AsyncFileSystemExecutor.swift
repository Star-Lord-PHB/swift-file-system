//
//  AsyncFileSystemExecutor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//


private import struct DequeModule.UniqueDeque
import struct FileSystemCore.PlatformError


public final class AsyncFileSystemExecutor: Sendable {
    
    public struct CalledOnceExecutorTask: ~Copyable {
        private let task: () -> Void
        public init(_ task: consuming sending @escaping () -> Void) { self.task = task }
        public consuming func callAsFunction() { task() }
    }
    
    
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
    
    
    public let label: String
    public let minimumThreadCount: Int
    public let maximumThreadCount: Int
    fileprivate let idleTimeout: MonotonicDuration
    fileprivate let storage: AtomicStorage
    
    public var state: State { storage.state }
    public var idleTimeoutNano: Int64 { idleTimeout.nanoseconds }

    
    public convenience init(label: String, threadCount: Int) {
        self.init(
            label: label,
            minimumThreadCount: threadCount,
            maximumThreadCount: threadCount,
            idleTimeout: .init(nanoseconds: .max)
        )
    }


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


    @concurrent
    public func run<R: ~Copyable, E: Error>(
        _ task: () throws(E) -> sending R
    ) async throws(E) -> sending R {

        return try await withoutActuallyEscaping(task) { (escapingClosure) async throws(E) in

            nonisolated(unsafe) var taskWrapper = escapingClosure as (() throws -> sending R)?

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


    public func runSending<R: ~Copyable, E: Error>(
        _ task: sending () throws(E) -> sending R
    ) async throws(E) -> sending R {
        return try await run(task)
    }

}



extension AsyncFileSystemExecutor {

    public enum Result<V: ~Copyable, E: Error>: ~Copyable {

        case success(V)
        case failure(E)
        case cancelled

        public consuming func get() throws -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw CancellationError()
            }
        }

        public consuming func get<C: Error>(mappingCancellation error: @autoclosure () -> C) throws -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw error()
            }
        }

        public consuming func get(mappingCancellation error: @autoclosure () -> E) throws(E) -> V {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw e
            case .cancelled: throw error()
            }
        }

        public consuming func get<C: Error>(mappingCancellation error: @autoclosure () -> C) throws(C) -> V where E == Never {
            switch consume self {
            case .success(let v): return v
            case .failure: preconditionFailure("unreachable")
            case .cancelled: throw error()
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

        public consuming func getThrowingPlatformError(
            operation: @autoclosure () -> PlatformError.Operation
        ) throws(PlatformError) -> V where E == LowLevelError {
            switch consume self {
            case .success(let v): return v
            case .failure(let e): throw .init(lowLevelError: e, operation: operation())
            case .cancelled: throw .init(error: CancellationError(), kind: .cancelled, operation: operation())
            }
        }

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

    @concurrent
    package func runCancellable<R: ~Copyable, E: Error>(
        _ task: () throws(E) -> sending R
    ) async -> sending Result<R, E> {

        guard !Task.isCancelled else {
            return .cancelled
        }

        let token = CancellationToken()

        return await withoutActuallyEscaping(task) { (escapingTask) async in

            nonisolated(unsafe) var taskWrapper = escapingTask as (() throws -> sending R)?

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


    /// Like `run(_:)`, but observes Swift task cancellation at two points: before the task
    /// is submitted, and on the worker thread right before the body starts. In both cases
    /// `cancellationError` is thrown and the body has not run (and never will); once the
    /// body has started it always runs to completion and its result is returned as usual,
    /// even if the task was cancelled in the meantime.
    ///
    /// Worker threads run outside any Swift task context (`Task.isCancelled` is always
    /// false there), so the in-queue check observes cancellation through a token set by
    /// `withTaskCancellationHandler` instead.
    ///
    /// Package-level on purpose: the signature forces the body and the cancellation error
    /// to share one error type, which fits this library (everything is `PlatformError`)
    /// but is too specific a constraint to publish.
    package func runCancellableSending<R: ~Copyable, E: Error>(
        _ task: sending () throws(E) -> sending R
    ) async -> sending Result<R, E> {
        return await runCancellable(task)
    }

}



extension AsyncFileSystemExecutor {

    /// Default `maximumThreadCount` for `defaultExecutor`. This is a burst-width cap, not a
    /// steady state: the pool starts at zero threads and shrinks back when idle. Blocking
    /// file I/O parallelism is bounded by the storage backend rather than the CPU, so the
    /// cap is a flat per-platform constant — wide on desktop/server platforms (deep NVMe
    /// queues, high-latency network file systems), trimmed on app-constrained Apple
    /// platforms where storage is local flash and the process-wide thread budget is shared
    /// with the host app.
    public static let defaultMaximumThreadCount: Int = {
        #if os(watchOS)
        return 8
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        return 32
        #else
        return 64
        #endif
    }()


    /// Shared process-wide pool, created on first use. Starts with zero threads, grows on
    /// demand up to `defaultMaximumThreadCount`, and shrinks back after the default idle
    /// timeout.
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

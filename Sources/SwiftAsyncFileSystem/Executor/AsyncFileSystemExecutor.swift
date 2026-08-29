//
//  AsyncFileSystemExecutor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//


import PlatformCLib
private import struct DequeModule.UniqueDeque
package import struct FileSystemCore.PlatformError


// TODO: Consider making the pool elastic (grow on demand, shrink when idle). The fixed
// eager pool is the main reason defaultThreadCount stays small; with elasticity a much
// wider cap becomes affordable for high-latency backends like network file systems.
public final class AsyncFileSystemExecutor: Sendable {
    
    public struct CalledOnceExecutorTask: ~Copyable {
        private let task: () -> Void
        public init(_ task: consuming sending @escaping () -> Void) { self.task = task }
        public consuming func callAsFunction() { task() }
    }
    
    
    public enum State: Sendable, Equatable, Hashable {
        case ready, running, stopped
    }
    
    
    fileprivate final class Storage {
        var state: State = .ready
        var tasks: UniqueDeque<CalledOnceExecutorTask> = .init()
    }
    
    
    fileprivate struct LockedCondition: Sendable {
        private unowned let cond: ConditionalVariable
        init(_ cond: ConditionalVariable) { self.cond = cond }
        func wait() {
            cond.wait()
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
    fileprivate let threads: [Thread]
    fileprivate let storage: AtomicStorage
    
    public var state: State { storage.state }
    
    
    public init(label: String, threadCount: Int) {

        precondition(threadCount > 0, "Executor needs at least one thread")

        self.label = label
        
        let storage = AtomicStorage()
        self.storage = storage
        
        self.threads = (0 ..< threadCount).map { i in
            .init(
                name: "\(label)-thread-\(i)",
                task: { Self.threadTask(storage) }
            )
        }
        
    }
    
    
    deinit {
        storage.withLock { storage, cond in
            storage.state = .stopped
            cond.broadcast()
        }
    }
    
    
    fileprivate static func threadTask(_ storage: AtomicStorage) {

        while true {
            
            let task = storage.withLock { storage, cond in
                
                while storage.state == .running && storage.tasks.isEmpty {
                    cond.wait()
                }
                
                if storage.state == .stopped {
                    return nil as CalledOnceExecutorTask?
                }
                
                guard let task = storage.tasks.popFirst() else {
                    preconditionFailure("Thread unexpectedly woken up with no task while executor is still running")
                }
                
                return task
                
            }
            
            guard let task else { break }
            
            task()
            
        }
        
    }
    
    
    public func start() {
        precondition(state == .ready, "Trying to start an already started executor")
        storage.withLock { storage, _ in
            storage.state = .running
        }
        for thread in threads {
            thread.start()
        }
    }
    
    
    public func submit(_ task: consuming sending CalledOnceExecutorTask) {
        precondition(state == .running, "Cannot submit tasks to an executor that is not running")
        var task = Optional.some(task)
        storage.withLock { storage, cond in
            storage.tasks.append(task.take()!)
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
    
    
    public func run<R: ~Copyable, E: Error>(
        _ task: sending () throws(E) -> sending R
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
                }.take()!
            } catch let error as E {
                throw error
            } catch {
                preconditionFailure()
            }
            
        }
        
    }
    
}


extension AsyncFileSystemExecutor {

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
    package func runCancellable<R: ~Copyable>(
        cancellationError: @autoclosure @Sendable @escaping () -> PlatformError,
        _ task: sending () throws(PlatformError) -> sending R
    ) async throws(PlatformError) -> sending R {

        guard !Task.isCancelled else {
            throw cancellationError()
        }

        let token = CancellationToken()

        return try await withoutActuallyEscaping(task) { (escapingClosure) async throws(PlatformError) in

            nonisolated(unsafe) var taskWrapper = escapingClosure as (() throws -> sending R)?

            do {
                let box = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NonCopyableBox<R>, any Error>) in
                        self.submit(.init { @Sendable in
                            guard !token.isCancelled else {
                                // Release the unused task reference before resuming: resuming
                                // lets `withoutActuallyEscaping` return, which traps if the
                                // closure is still referenced at that point.
                                taskWrapper = nil
                                continuation.resume(throwing: cancellationError())
                                return
                            }
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
                } onCancel: {
                    token.cancel()
                }
                return box.take()!
            } catch let error as PlatformError {
                throw error
            } catch {
                preconditionFailure()
            }

        }

    }


    /// Convenience overload for the common case: cancellation surfaces as the library's
    /// standard cancellation error — kind `.cancelled`, a `CancellationError` as the
    /// underlying error, no system code — carrying the given operation context.
    package func runCancellable<R: ~Copyable>(
        operation: PlatformError.Operation,
        _ task: sending () throws(PlatformError) -> sending R
    ) async throws(PlatformError) -> sending R {
        return try await runCancellable(
            cancellationError: PlatformError(error: CancellationError(), kind: .cancelled, operation: operation),
            task
        )
    }

}



extension AsyncFileSystemExecutor {

    /// Thread count used by `defaultExecutor`: the number of online processors clamped to
    /// [2, 8]. Blocking file I/O parallelism is bounded by the storage device, so wider
    /// pools mostly add idle threads.
    public static let defaultThreadCount: Int = {
        #if canImport(WinSDK)
        var info = SYSTEM_INFO()
        GetSystemInfo(&info)
        let processorCount = Int(info.dwNumberOfProcessors)
        #else
        let processorCount = sysconf(Int32(_SC_NPROCESSORS_ONLN))
        #endif
        return max(2, min(8, processorCount))
    }()


    /// Shared process-wide pool, created and started on first use.
    public static let defaultExecutor: AsyncFileSystemExecutor = {
        let executor = AsyncFileSystemExecutor(
            label: "swift-file-system-default-executor",
            threadCount: defaultThreadCount
        )
        executor.start()
        return executor
    }()

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

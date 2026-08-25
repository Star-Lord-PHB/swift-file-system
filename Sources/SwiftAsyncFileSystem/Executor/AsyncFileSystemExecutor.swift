//
//  AsyncFileSystemExecutor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//


private import struct DequeModule.UniqueDeque


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


@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension AsyncFileSystemExecutor: TaskExecutor {
    
    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        self.submit(.init {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        })
    }
    
}

import Foundation
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem


extension AsyncFileSystemExecutorTests {

    @Suite("RunCancellable")
    struct RunCancellableTests {}

}



extension AsyncFileSystemExecutorTests.RunCancellableTests {

    typealias SharedBox<Value> = AsyncFileSystemExecutorTests.SharedBox<Value>


    /// The shape the async API layer will use: `.cancelled` kind carrying a
    /// `CancellationError` as the underlying error, no system code.
    static func stubCancellationError(operationName: PlatformError.CustomOperationName) -> PlatformError {
        .init(error: CancellationError(), kind: .cancelled, operation: .custom(name: operationName))
    }


    static func countingCancellationError(_ constructions: SharedBox<Int>) -> PlatformError {
        constructions.value += 1
        return stubCancellationError(operationName: "counting")
    }


    // MARK: - Pass-through behavior (no cancellation involved)

    @Test
    func `runCancellable returns the value produced by the task`() async throws {
        let executor = AsyncFileSystemExecutor(label: "cxl1", threadCount: 2)

        let value = try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "unused")) { 21 * 2 }
        #expect(value == 42)
    }


    @Test
    func `runCancellable supports noncopyable results`() async throws {
        struct Payload: ~Copyable {
            let value: Int
        }

        let executor = AsyncFileSystemExecutor(label: "cxlNC", threadCount: 1)

        let payload = try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "unused")) { Payload(value: 9) }
        #expect(payload.value == 9)
    }


    @Test
    func `runCancellable rethrows the error thrown by the task`() async {
        let executor = AsyncFileSystemExecutor(label: "cxlE", threadCount: 1)

        let error = await #expect(throws: PlatformError.self) {
            try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "unused")) { () throws(PlatformError) -> Void in
                throw PlatformError(error: CocoaError(.fileNoSuchFile), kind: .invalidInput, operation: .custom(name: "body-failure"))
            }
        }
        #expect(error?.kind == .invalidInput)
        #expect(error?.operation == .custom(name: "body-failure"))
    }


    @Test
    func `the cancellation error is only constructed when cancellation fires`() async throws {
        let executor = AsyncFileSystemExecutor(label: "cxlLazy", threadCount: 1)

        let constructions = SharedBox(0)
        let value = try await executor.runCancellable(cancellationError: Self.countingCancellationError(constructions)) { 7 }
        #expect(value == 7)
        #expect(constructions.value == 0)
    }


    // MARK: - Cancellation checkpoints

    @Test(.timeLimit(.minutes(1)))
    func `an already cancelled task throws the cancellation error without running the body`() async {
        let executor = AsyncFileSystemExecutor(label: "cxlPre", threadCount: 1)

        let bodyRan = SharedBox(false)
        let task = Task {
            // Guarantee the cancellation is observable before runCancellable is entered, so
            // this deterministically exercises the pre-submit check.
            while !Task.isCancelled { await Task.yield() }
            return try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "pre-check")) { () throws(PlatformError) -> Int in
                bodyRan.value = true
                return 1
            }
        }
        task.cancel()

        let error = await #expect(throws: PlatformError.self) {
            try await task.value
        }
        #expect(error?.kind == .cancelled)
        #expect(error?.operation == .custom(name: "pre-check"))
        #expect(error?.underlyingError is CancellationError)
        #expect(bodyRan.value == false)
    }


    @Test(.timeLimit(.minutes(1)))
    func `the operation overload produces the standard cancellation error`() async {
        let executor = AsyncFileSystemExecutor(label: "cxlOp", threadCount: 1)

        let bodyRan = SharedBox(false)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await executor.runCancellable(operation: .custom(name: "op-overload")) { () throws(PlatformError) -> Int in
                bodyRan.value = true
                return 1
            }
        }
        task.cancel()

        let error = await #expect(throws: PlatformError.self) {
            try await task.value
        }
        #expect(error?.kind == .cancelled)
        #expect(error?.operation == .custom(name: "op-overload"))
        #expect(error?.underlyingError is CancellationError)
        #expect(error?.systemCode == nil)
        #expect(bodyRan.value == false)
    }


    @Test(.timeLimit(.minutes(1)))
    func `cancellation while the task waits in the queue throws without running the body`() async {
        let executor = AsyncFileSystemExecutor(label: "cxlQ", threadCount: 1)

        let condition = NSCondition()
        let released = SharedBox(false)
        let (workerBlocked, workerBlockedContinuation) = AsyncStream.makeStream(of: Void.self)

        // Occupy the only worker so the cancellable task stays queued behind it.
        executor.submit(.init {
            workerBlockedContinuation.yield()
            condition.lock()
            while !released.value {
                condition.wait()
            }
            condition.unlock()
        })

        for await _ in workerBlocked.prefix(1) {}

        let bodyRan = SharedBox(false)
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let task = Task {
            enteredContinuation.yield()
            return try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "queue-check")) { () throws(PlatformError) -> Int in
                bodyRan.value = true
                return 2
            }
        }

        for await _ in entered.prefix(1) {}
        // Give the call a moment to reach submit so the worker-side check is what usually
        // fires; if cancellation still wins the race, the pre-submit check reports the same
        // outcome, so the test stays deterministic either way.
        await Task.yield()
        task.cancel()

        condition.withLock {
            released.value = true
            condition.broadcast()
        }

        let error = await #expect(throws: PlatformError.self) {
            try await task.value
        }
        #expect(error?.kind == .cancelled)
        #expect(error?.operation == .custom(name: "queue-check"))
        #expect(bodyRan.value == false)
    }


    @Test(.timeLimit(.minutes(1)))
    func `cancellation after the body has started does not affect its result`() async throws {
        let executor = AsyncFileSystemExecutor(label: "cxlMid", threadCount: 1)

        let condition = NSCondition()
        let released = SharedBox(false)
        let (bodyStarted, bodyStartedContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task {
            try await executor.runCancellable(cancellationError: Self.stubCancellationError(operationName: "unused")) { () throws(PlatformError) -> Int in
                bodyStartedContinuation.yield()
                condition.lock()
                while !released.value {
                    condition.wait()
                }
                condition.unlock()
                return 42
            }
        }

        for await _ in bodyStarted.prefix(1) {}
        task.cancel()

        condition.withLock {
            released.value = true
            condition.broadcast()
        }

        #expect(try await task.value == 42)
    }

}

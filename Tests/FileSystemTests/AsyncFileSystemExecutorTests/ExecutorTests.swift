import Foundation
import Testing
import SwiftAsyncFileSystem


extension AsyncFileSystemExecutorTests {

    @Suite("AsyncFileSystemExecutor")
    struct ExecutorTests {}

}



extension AsyncFileSystemExecutorTests.ExecutorTests {

    typealias SharedBox<Value> = AsyncFileSystemExecutorTests.SharedBox<Value>


    struct RunFailure: Error, Equatable {
        let code: Int
    }


    // MARK: - State & lifecycle

    @Test
    func `executor starts in the ready state and start moves it to running`() {
        let executor = AsyncFileSystemExecutor(label: "st", threadCount: 1)
        #expect(executor.label == "st")
        #expect(executor.state == .ready)
        executor.start()
        #expect(executor.state == .running)
    }


    @Test
    func `executor deallocates after the last reference is dropped`() async {
        weak var weakExecutor: AsyncFileSystemExecutor?
        do {
            let executor = AsyncFileSystemExecutor(label: "gone", threadCount: 2)
            executor.start()
            await executor.run {}
            weakExecutor = executor
        }
        #expect(weakExecutor == nil)
    }


    // MARK: - submit

    @Test(.timeLimit(.minutes(1)))
    func `every submitted task runs exactly once`() async {
        let executor = AsyncFileSystemExecutor(label: "subN", threadCount: 4)
        executor.start()

        let (indices, continuation) = AsyncStream.makeStream(of: Int.self)
        for index in 0 ..< 100 {
            executor.submit(.init { continuation.yield(index) })
        }

        let values = await indices.prefix(100).reduce(into: [Int]()) { $0.append($1) }
        #expect(values.sorted() == Array(0 ..< 100))
    }


    @Test(.timeLimit(.minutes(1)))
    func `the pool runs tasks concurrently up to its thread count`() async {
        let executor = AsyncFileSystemExecutor(label: "par", threadCount: 4)
        executor.start()

        let condition = NSCondition()
        let released = SharedBox(false)
        let (arrivals, arrivalContinuation) = AsyncStream.makeStream(of: Void.self)
        let (completions, completionContinuation) = AsyncStream.makeStream(of: Void.self)

        // Each task blocks until the test observed all four inside the pool simultaneously,
        // so the test only completes if four workers really run concurrently.
        for _ in 0 ..< 4 {
            executor.submit(.init {
                arrivalContinuation.yield()
                condition.lock()
                while !released.value {
                    condition.wait()
                }
                condition.unlock()
                completionContinuation.yield()
            })
        }

        for await _ in arrivals.prefix(4) {}

        condition.withLock {
            released.value = true
            condition.broadcast()
        }

        for await _ in completions.prefix(4) {}
    }


    // MARK: - run()

    @Test
    func `run returns the value produced by the task`() async {
        let executor = AsyncFileSystemExecutor(label: "run1", threadCount: 2)
        executor.start()

        let value = await executor.run { 21 * 2 }
        #expect(value == 42)
    }


    @Test
    func `run executes its task exactly once`() async {
        let executor = AsyncFileSystemExecutor(label: "once", threadCount: 2)
        executor.start()

        await confirmation("run executed the task") { executed in
            await executor.run { executed() }
        }
    }


    @Test
    func `run supports noncopyable results`() async {
        struct Payload: ~Copyable {
            let value: Int
        }

        let executor = AsyncFileSystemExecutor(label: "runNC", threadCount: 1)
        executor.start()

        let payload = await executor.run { Payload(value: 9) }
        #expect(payload.value == 9)
    }


    @Test
    func `run rethrows the typed error thrown by the task`() async {
        let executor = AsyncFileSystemExecutor(label: "runE", threadCount: 1)
        executor.start()

        await #expect(throws: RunFailure(code: 7)) {
            try await executor.run { throw RunFailure(code: 7) }
        }
    }


    @Test
    func `concurrent runs complete with their own results`() async {
        let executor = AsyncFileSystemExecutor(label: "many", threadCount: 4)
        executor.start()

        let total = await withTaskGroup(of: Int.self) { group in
            for index in 0 ..< 64 {
                group.addTask {
                    await executor.run { index * 2 }
                }
            }
            return await group.reduce(0, +)
        }
        #expect(total == 64 * 63)
    }


    // MARK: - Pool thread identity

    // FreeBSD/OpenBSD skip thread naming, so the name-asserting tests are omitted there.
    #if !os(FreeBSD) && !os(OpenBSD)

    @Test(.timeLimit(.minutes(1)))
    func `submitted task runs on the labeled pool thread`() async {
        let executor = AsyncFileSystemExecutor(label: "sub1", threadCount: 1)
        executor.start()

        let (names, continuation) = AsyncStream.makeStream(of: String.self)
        executor.submit(.init {
            continuation.yield(AsyncFileSystemExecutorTests.foundationCurrentThreadName() ?? "<unnamed>")
        })

        let observed = await names.first { _ in true }
        #expect(observed == "sub1-thread-0")
    }


    @Test
    func `run executes its task on the labeled pool thread`() async {
        let executor = AsyncFileSystemExecutor(label: "run2", threadCount: 1)
        executor.start()

        let name = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(name == "run2-thread-0")
    }


    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @Test
    func `executor can serve as a task executor preference`() async {
        let executor = AsyncFileSystemExecutor(label: "texec", threadCount: 1)
        executor.start()

        let name = await Task(executorPreference: executor) {
            AsyncFileSystemExecutorTests.foundationCurrentThreadName()
        }.value
        #expect(name == "texec-thread-0")
    }

    #endif

}

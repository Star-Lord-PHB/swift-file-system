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
    func `executor is running from construction`() {
        let fixed = AsyncFileSystemExecutor(label: "st", threadCount: 2)
        #expect(fixed.label == "st")
        #expect(fixed.state == .running)
        #expect(fixed.minimumThreadCount == 2)
        #expect(fixed.maximumThreadCount == 2)

        let elastic = AsyncFileSystemExecutor(label: "el", maximumThreadCount: 4, idleTimeout: .milliseconds(50))
        #expect(elastic.state == .running)
        #expect(elastic.minimumThreadCount == 0)
        #expect(elastic.maximumThreadCount == 4)
        #expect(elastic.idleTimeoutNano == 50_000_000)
    }


    @Test
    func `executor deallocates after the last reference is dropped`() async {
        weak var weakExecutor: AsyncFileSystemExecutor?
        do {
            let executor = AsyncFileSystemExecutor(label: "gone", maximumThreadCount: 2)
            await executor.run {}
            weakExecutor = executor
        }
        #expect(weakExecutor == nil)
    }


    // MARK: - submit & elasticity

    @Test(.timeLimit(.minutes(1)))
    func `every submitted task runs exactly once`() async {
        let executor = AsyncFileSystemExecutor(label: "subN", maximumThreadCount: 4)

        let (indices, continuation) = AsyncStream.makeStream(of: Int.self)
        for index in 0 ..< 100 {
            executor.submit(.init { continuation.yield(index) })
        }

        let values = await indices.prefix(100).reduce(into: [Int]()) { $0.append($1) }
        #expect(values.sorted() == Array(0 ..< 100))
    }


    // The (1, 2) case is the regression guard for idle pre-seeding: growth must also
    // happen while every persistent thread is blocked inside a task.
    @Test(
        .timeLimit(.minutes(1)),
        arguments: [
            (0, 4),
            (1, 2),
        ] as [(Int, Int)]
    )
    func `the pool grows on demand to run tasks concurrently up to its maximum`(
        minimumThreadCount: Int, maximumThreadCount: Int
    ) async {
        let executor = AsyncFileSystemExecutor(
            label: "par",
            minimumThreadCount: minimumThreadCount,
            maximumThreadCount: maximumThreadCount
        )

        let condition = NSCondition()
        let released = SharedBox(false)
        let (arrivals, arrivalContinuation) = AsyncStream.makeStream(of: Void.self)
        let (completions, completionContinuation) = AsyncStream.makeStream(of: Void.self)

        // Every task blocks until all of them sit inside the pool simultaneously, so the
        // test only completes if the pool grew to `maximumThreadCount` concurrent workers.
        for _ in 0 ..< maximumThreadCount {
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

        for await _ in arrivals.prefix(maximumThreadCount) {}

        condition.withLock {
            released.value = true
            condition.broadcast()
        }

        for await _ in completions.prefix(maximumThreadCount) {}
    }


    @Test(.timeLimit(.minutes(1)))
    func `the pool never runs more tasks concurrently than its maximum`() async {
        let executor = AsyncFileSystemExecutor(label: "cap", maximumThreadCount: 1)

        let lock = NSLock()
        let counters = SharedBox((current: 0, peak: 0))
        let (completions, continuation) = AsyncStream.makeStream(of: Void.self)

        for _ in 0 ..< 3 {
            executor.submit(.init {
                lock.withLock {
                    counters.value.current += 1
                    counters.value.peak = max(counters.value.peak, counters.value.current)
                }
                Thread.sleep(forTimeInterval: 0.02)
                lock.withLock {
                    counters.value.current -= 1
                }
                continuation.yield()
            })
        }

        for await _ in completions.prefix(3) {}
        #expect(lock.withLock { counters.value.peak } == 1)
    }


    // MARK: - run()

    @Test
    func `run returns the value produced by the task`() async {
        let executor = AsyncFileSystemExecutor(label: "run1", threadCount: 2)
        let value = await executor.run { 21 * 2 }
        #expect(value == 42)
    }


    @Test
    func `run executes its task exactly once`() async {
        let executor = AsyncFileSystemExecutor(label: "once", maximumThreadCount: 2)
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
        let payload = await executor.run { Payload(value: 9) }
        #expect(payload.value == 9)
    }


    @Test
    func `run rethrows the typed error thrown by the task`() async {
        let executor = AsyncFileSystemExecutor(label: "runE", maximumThreadCount: 1)
        await #expect(throws: RunFailure(code: 7)) {
            try await executor.run { throw RunFailure(code: 7) }
        }
    }


    @Test
    func `concurrent runs complete with their own results`() async {
        let executor = AsyncFileSystemExecutor(label: "many", maximumThreadCount: 4)
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


    @Test
    func `the shared default executor runs work`() async {
        let executor = AsyncFileSystemExecutor.defaultExecutor
        #expect(executor.label == "fs-io")
        #expect(executor.minimumThreadCount == 0)
        #expect(executor.maximumThreadCount == AsyncFileSystemExecutor.defaultMaximumThreadCount)
        #expect(AsyncFileSystemExecutor.defaultMaximumThreadCount > 0)

        let value = await executor.run { 7 }
        #expect(value == 7)
    }


    // MARK: - Pool thread identity & elasticity observed through names

    // FreeBSD/OpenBSD skip thread naming, so the name-based tests are omitted there.
    #if !os(FreeBSD) && !os(OpenBSD)

    @Test(.timeLimit(.minutes(1)))
    func `submitted task runs on the labeled pool thread`() async {
        let executor = AsyncFileSystemExecutor(label: "sub1", maximumThreadCount: 1)

        let (names, continuation) = AsyncStream.makeStream(of: String.self)
        executor.submit(.init {
            continuation.yield(AsyncFileSystemExecutorTests.foundationCurrentThreadName() ?? "<unnamed>")
        })

        let observed = await names.first { _ in true }
        #expect(observed == "sub1-0")
    }


    @Test
    func `run executes its task on the labeled pool thread`() async {
        let executor = AsyncFileSystemExecutor(label: "run2", threadCount: 1)
        let name = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(name == "run2-0")
    }


    @Test
    func `an overlong label is truncated while the thread id survives`() async {
        let executor = AsyncFileSystemExecutor(label: "abcdefghijklmnopqrst", maximumThreadCount: 1)
        let name = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(name == "abcdefghijklm-0")
    }


    @Test
    func `an elastic thread above the minimum retires after the idle timeout`() async throws {
        let executor = AsyncFileSystemExecutor(label: "shr", maximumThreadCount: 1, idleTimeout: .milliseconds(50))

        let first = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(first == "shr-0")

        // Far past the idle timeout: the sole worker must have retired by now.
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // A retired worker leaves no idle thread, so this run spawns a fresh one, visible
        // through the monotonic id in its name.
        let second = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(second == "shr-1")
    }


    @Test
    func `persistent threads outlive the idle timeout`() async throws {
        let executor = AsyncFileSystemExecutor(
            label: "per",
            minimumThreadCount: 1,
            maximumThreadCount: 1,
            idleTimeout: .milliseconds(50)
        )

        let first = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(first == "per-0")

        try await Task.sleep(nanoseconds: 300_000_000)

        let second = await executor.run { AsyncFileSystemExecutorTests.foundationCurrentThreadName() }
        #expect(second == "per-0")
    }


    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @Test
    func `executor can serve as a task executor preference`() async {
        let executor = AsyncFileSystemExecutor(label: "texec", threadCount: 1)
        let name = await Task(executorPreference: executor) {
            AsyncFileSystemExecutorTests.foundationCurrentThreadName()
        }.value
        #expect(name == "texec-0")
    }

    #endif

}

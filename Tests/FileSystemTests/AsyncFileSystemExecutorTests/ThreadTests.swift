import Testing
@testable import SwiftAsyncFileSystem


extension AsyncFileSystemExecutorTests {

    @Suite("Thread & ConditionalVariable")
    struct ThreadTests {}

}



extension AsyncFileSystemExecutorTests.ThreadTests {

    typealias SharedBox<Value> = AsyncFileSystemExecutorTests.SharedBox<Value>


    @Test
    func `task runs on a started thread and join makes its effects visible`() {
        let result = SharedBox(0)
        let thread = Thread(name: "fs-test-worker") {
            result.value = 42
        }
        thread.start()
        thread.join()
        #expect(result.value == 42)
    }


    // FreeBSD/OpenBSD skip naming (no API through the imported libc), so the name tests
    // are omitted there.
    #if !os(FreeBSD) && !os(OpenBSD)

    @Test
    func `thread name is applied to the spawned thread`() {
        let observedName = SharedBox(nil as String?)
        let thread = Thread(name: "fs-io-test") {
            observedName.value = AsyncFileSystemExecutorTests.foundationCurrentThreadName()
        }
        thread.start()
        thread.join()
        #expect(observedName.value == "fs-io-test")
    }


    @Test
    func `overlong thread name is applied within platform limits`() {
        let longName = "thread-name-overflow-check"
        let observedName = SharedBox(nil as String?)
        let thread = Thread(name: longName) {
            observedName.value = AsyncFileSystemExecutorTests.foundationCurrentThreadName()
        }
        thread.start()
        thread.join()

        #if canImport(WinSDK) || canImport(Darwin)
        #expect(observedName.value == longName)
        #else
        #expect(observedName.value == String(decoding: longName.utf8.prefix(15), as: UTF8.self))
        #endif
    }

    #endif


    @Test
    func `lock provides mutual exclusion across threads`() {
        let condition = ConditionalVariable()
        let counter = SharedBox(0)
        let threads = (0 ..< 8).map { _ in
            Thread {
                for _ in 0 ..< 1000 {
                    condition.lock()
                    counter.value += 1
                    condition.unlock()
                }
            }
        }
        threads.forEach { $0.start() }
        threads.forEach { $0.join() }
        #expect(counter.value == 8000)
    }


    @Test
    func `producer-consumer handshake through wait and signal`() {
        let condition = ConditionalVariable()
        let state = SharedBox((pending: [Int](), consumed: [Int](), finished: false))

        let consumer = Thread {
            while true {
                condition.lock()
                while state.value.pending.isEmpty && !state.value.finished {
                    condition.wait()
                }
                if state.value.pending.isEmpty {
                    condition.unlock()
                    return
                }
                let item = state.value.pending.removeFirst()
                state.value.consumed.append(item)
                condition.unlock()
            }
        }
        consumer.start()

        for item in 0 ..< 100 {
            condition.lock()
            state.value.pending.append(item)
            condition.signal()
            condition.unlock()
        }
        condition.lock()
        state.value.finished = true
        condition.signal()
        condition.unlock()

        consumer.join()
        #expect(state.value.consumed == Array(0 ..< 100))
    }


    @Test
    func `broadcast wakes every waiting thread`() {
        let condition = ConditionalVariable()
        let gate = SharedBox((open: false, arrived: 0))

        let waiters = (0 ..< 4).map { _ in
            Thread {
                condition.lock()
                gate.value.arrived += 1
                condition.broadcast()
                while !gate.value.open {
                    condition.wait()
                }
                condition.unlock()
            }
        }
        waiters.forEach { $0.start() }

        condition.lock()
        while gate.value.arrived < 4 {
            condition.wait()
        }
        gate.value.open = true
        condition.broadcast()
        condition.unlock()

        waiters.forEach { $0.join() }
    }


    @Test
    func `withLock returns the body's value`() {
        let condition = ConditionalVariable()
        let value = condition.withLock { 7 }
        #expect(value == 7)
    }


    @Test
    func `wait inside withLock releases and reacquires the lock`() {
        let condition = ConditionalVariable()
        let flag = SharedBox(false)

        let signaler = Thread {
            condition.withLock {
                flag.value = true
                condition.signal()
            }
        }
        signaler.start()

        condition.withLock {
            while !flag.value {
                condition.wait()
            }
        }
        signaler.join()
        #expect(flag.value)
    }


    @Test
    func `monotonic instants are non-decreasing and do arithmetic`() {
        let start = MonotonicInstant.now()
        let end = MonotonicInstant.now()
        #expect(start <= end)

        #expect(MonotonicDuration.seconds(1) == .milliseconds(1_000))
        #expect(MonotonicDuration.milliseconds(1) == .microseconds(1_000))
        #expect(MonotonicDuration.microseconds(1) == .nanoseconds(1_000))

        let later = start + .milliseconds(5)
        #expect(later > start)
        #expect(later - start == .milliseconds(5))
    }


    @Test
    func `timed wait returns false once the deadline passes`() {
        let condition = ConditionalVariable()
        let start = MonotonicInstant.now()
        let deadline = start + .milliseconds(50)

        condition.lock()
        // No signaler exists, but the platform contract still allows spurious wakeups
        // (wait returning true); re-waiting with the same deadline keeps the test
        // deterministic instead of codifying "no spurious wakeups" as an assumption.
        while condition.wait(until: deadline) {}
        condition.unlock()

        // A false return guarantees the deadline passed on MonotonicInstant's own clock.
        #expect(MonotonicInstant.now() - start >= .milliseconds(50))
    }


    @Test
    func `timed wait wakes on signal before the deadline`() {
        let condition = ConditionalVariable()
        let flag = SharedBox(false)
        let deadline = MonotonicInstant.now() + .seconds(30)

        let signaler = Thread {
            condition.lock()
            flag.value = true
            condition.signal()
            condition.unlock()
        }

        condition.lock()
        signaler.start()
        var sawTimeout = false
        // Loops only when a spurious wakeup fires before the signaler set the flag; the
        // timeout arm is the failure path, turning a lost signal into a loud assertion
        // failure instead of an unbounded hang.
        while !flag.value && !sawTimeout {
            sawTimeout = !condition.wait(until: deadline)
        }
        condition.unlock()
        signaler.join()

        #expect(flag.value)
        #expect(!sawTimeout)
    }

}

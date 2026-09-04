import Testing
import SwiftAsyncFileSystem



// NOTE: Each handle kind has its own close() and its own `withUnsafeSystemHandle` plumbing,
// so the release contract is pinned per kind. `SystemHandleProbe` is captured through the
// async `withUnsafeSystemHandle` and re-queried after the release.
extension AsyncFileHandleAPITests.LifecycleTests {

    @Test
    func `AsyncReadFileHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncWriteFileHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncReadWriteFileHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncAppendHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncAppendHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncStreamingReadHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncStreamingWriteHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AsyncStreamingReadWriteHandle close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncStreamingReadWriteHandle(forFileAt: path)
        let probe = try await handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try await handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `Dropping a handle without close releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let probe: Support.SystemHandleProbe

        do {
            let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
            probe = try await handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
        }

        #expect(probe.isReleased)

    }


    // A handle a view was derived from cannot be consumed in the same scope afterwards, so
    // the release of a handle that served a view always goes through deinit.
    @Test
    func `Dropping a handle after deriving a view releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let probe: Support.SystemHandleProbe

        do {
            let handle = try await AsyncReadFileHandle(forFileAt: path)
            probe = try await handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            var reader = handle.sequentialReader()
            #expect(try await reader.read(length: 8) == ByteBuffer("contents".utf8))
        }

        #expect(probe.isReleased)

    }


    @Test
    func `Dropping a write handle without close preserves written data`() async throws {

        let path = workspace.path("file")

        do {
            let handle = try await AsyncWriteFileHandle(forFileAt: path, options: .newFile())
            #expect(try await handle.write(ByteBuffer("contents".utf8), toOffset: 0) == 8)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    // close() never observes cancellation: the handle is consumed either way, so a cancelled
    // task still releases it through the executor. The handle is opened inside the task (a
    // captured handle could not be consumed there, and an open issued after the cancellation
    // would report `.cancelled` itself), which signals once the handle is open and only then
    // gets cancelled.
    @Test(.timeLimit(.minutes(1)))
    func `Pre-cancelled close still releases the system handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let (opened, openedContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task {
            let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
            let probe = try await handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            openedContinuation.yield()
            while !Task.isCancelled { await Task.yield() }
            try await handle.close()
            return probe.isReleased
        }
        for await _ in opened.prefix(1) {}
        task.cancel()

        #expect(try await task.value)

    }

}

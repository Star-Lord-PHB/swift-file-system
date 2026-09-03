#if canImport(WinSDK)

import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.StreamingReadTests {

    @Suite("Windows named pipes")
    struct WindowsPipeTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The two pipe end-of-file alignments (ERROR_BROKEN_PIPE after a server close,
// ERROR_PIPE_NOT_CONNECTED after a disconnect) live in the synchronous sequential read
// extension; seeing them through the async handle proves the read is routed to that path and
// not to the positional one. The pending-read test adds the shape that only exists with the
// executor.
extension AsyncFileHandleAPITests.StreamingReadTests.WindowsPipeTests {

    @Test
    func `Reads drain a named pipe and see EOF after the server closes`() async throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try await AsyncStreamingReadHandle(forFileAt: server.path)

        #expect(try await handle.type() == .fifo)

        try server.write(Array("hello".utf8))
        server.close()

        #expect(try await handle.read(length: 3) == ByteBuffer("hel".utf8))
        #expect(try await handle.read(length: 4) == ByteBuffer("lo".utf8))
        #expect(try await handle.read(length: 2).isEmpty)

        try await handle.close()

    }


    @Test
    func `A disconnected pipe reads as EOF`() async throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try await AsyncStreamingReadHandle(forFileAt: server.path)

        server.disconnect()

        #expect(try await handle.read(length: 4).isEmpty)

        try await handle.close()

    }


    // Whether the read is already pending on a pool thread when the server writes is
    // timing-dependent; the outcome is the same either way.
    @Test(.timeLimit(.minutes(1)))
    func `A read waiting for data is completed by a server write`() async throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try await AsyncStreamingReadHandle(forFileAt: server.path)

        let readerTask = Task {
            try await handle.read(length: 5)
        }

        try server.write(Array("hello".utf8))

        #expect(try await readerTask.value == ByteBuffer("hello".utf8))

        server.close()

    }

}

#endif

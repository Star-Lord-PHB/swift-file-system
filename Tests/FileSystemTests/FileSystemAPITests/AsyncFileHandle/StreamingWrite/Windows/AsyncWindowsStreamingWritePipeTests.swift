#if canImport(WinSDK)

import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.StreamingWriteTests {

    @Suite("Windows named pipes")
    struct WindowsPipeTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.StreamingWriteTests.WindowsPipeTests {

    @Test
    func `Writes reach the named-pipe server`() async throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try await AsyncStreamingWriteHandle(forFileAt: server.path)

        #expect(try await handle.write(ByteBuffer("hello".utf8)) == 5)
        #expect(try server.read(upTo: 5) == Array("hello".utf8))

        try await handle.close()

    }


    @Test
    func `Writing after the server disconnects reports brokenPipe`() async throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try await AsyncStreamingWriteHandle(forFileAt: server.path)

        server.disconnect()

        let error = await #expect(throws: PlatformError.self) {
            try await handle.write(ByteBuffer("x".utf8))
        }

        #expect(error?.kind == .brokenPipe)

        // The non-Sendable handle was captured by the expectation closure above, so it cannot
        // be handed to a @concurrent close afterwards; deinit releases it.

    }

}

#endif

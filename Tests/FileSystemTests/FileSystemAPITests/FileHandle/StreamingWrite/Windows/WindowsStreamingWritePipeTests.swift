#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingWriteTests {

    @Suite("Windows named pipes")
    struct WindowsPipeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.StreamingWriteTests.WindowsPipeTests {

    @Test
    func `Writes reach the named-pipe server`() throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try StreamingWriteHandle(forFileAt: server.path)

        #expect(try handle.write(ByteBuffer("hello".utf8)) == 5)
        #expect(try server.read(upTo: 5) == Array("hello".utf8))

        try handle.close()

    }


    @Test
    func `Writing after the server disconnects reports brokenPipe`() throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try StreamingWriteHandle(forFileAt: server.path)

        server.disconnect()

        let error = #expect(throws: PlatformError.self) {
            try handle.write(ByteBuffer("x".utf8))
        }

        #expect(error?.kind == .brokenPipe)

        try handle.close()

    }

}

#endif

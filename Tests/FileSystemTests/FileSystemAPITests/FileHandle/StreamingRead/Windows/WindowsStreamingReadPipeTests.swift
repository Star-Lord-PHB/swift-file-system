#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingReadTests {

    @Suite("Windows named pipes")
    struct WindowsPipeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.StreamingReadTests.WindowsPipeTests {

    @Test
    func `Reads drain a named pipe and see EOF after the server closes`() throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try StreamingReadHandle(forFileAt: server.path)

        #expect(try handle.type() == .fifo)

        try server.write(Array("hello".utf8))
        server.close()

        #expect(try handle.read(length: 3) == ByteBuffer("hel".utf8))
        #expect(try handle.read(length: 4) == ByteBuffer("lo".utf8))
        #expect(try handle.read(length: 2).isEmpty)

        try handle.close()

    }


    @Test
    func `A disconnected pipe reads as EOF`() throws {

        let server = try Support.WindowsNamedPipeServer(
            uniqueToken: workspace.root.lastComponent!.string
        )

        let handle = try StreamingReadHandle(forFileAt: server.path)

        server.disconnect()

        #expect(try handle.read(length: 4).isEmpty)

        try handle.close()

    }

}

#endif

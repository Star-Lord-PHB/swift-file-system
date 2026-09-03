#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.StreamingReadWriteTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.StreamingReadWriteTests.POSIXFifoTests {

    // The read-write FIFO open (daemon pattern: the handle's own write end keeps the FIFO
    // alive) is synchronous open semantics; through the async handle it is the one FIFO shape
    // where reads and writes of a single handle interleave with a transient raw writer.
    @Test
    func `Opens a FIFO with no peer and stays usable across writers`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try await AsyncStreamingReadWriteHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("self".utf8)) == 4)
        #expect(try await handle.read(length: 4) == ByteBuffer("self".utf8))

        // A transient writer connects right away because the handle already holds a read end.
        let writerDescriptor = PlatformCLib.open(path.string, O_WRONLY)
        try #require(writerDescriptor >= 0)
        try #require("ping".withCString { write(writerDescriptor, $0, 4) } == 4)
        try #require(PlatformCLib.close(writerDescriptor) == 0)

        #expect(try await handle.read(length: 4) == ByteBuffer("ping".utf8))

        // The FIFO stays usable after that writer left instead of reading as end-of-file.
        #expect(try await handle.write(ByteBuffer("pong".utf8)) == 4)
        #expect(try await handle.read(length: 4) == ByteBuffer("pong".utf8))

        try await handle.close()

    }

}

#endif

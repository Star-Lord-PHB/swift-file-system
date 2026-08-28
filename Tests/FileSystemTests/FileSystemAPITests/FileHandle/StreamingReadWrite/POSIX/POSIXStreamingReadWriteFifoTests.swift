#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingReadWriteTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.StreamingReadWriteTests.POSIXFifoTests {

    // POSIX leaves a read-write FIFO open undefined, but Linux, Darwin and the BSDs all
    // support it, and it is the classic daemon pattern: the handle's own write end keeps
    // the FIFO alive, so transient writers do not turn into end-of-file.
    @Test
    func `Opens a FIFO with no peer and stays usable across writers`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try StreamingReadWriteHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("self".utf8)) == 4)
        #expect(try handle.read(length: 4) == ByteBuffer("self".utf8))

        // A transient writer connects right away because the handle already holds a read end.
        let writerDescriptor = PlatformCLib.open(path.string, O_WRONLY)
        try #require(writerDescriptor >= 0)
        try #require("ping".withCString { write(writerDescriptor, $0, 4) } == 4)
        try #require(PlatformCLib.close(writerDescriptor) == 0)

        #expect(try handle.read(length: 4) == ByteBuffer("ping".utf8))

        // The FIFO stays usable after that writer left instead of reading as end-of-file.
        #expect(try handle.write(ByteBuffer("pong".utf8)) == 4)
        #expect(try handle.read(length: 4) == ByteBuffer("pong".utf8))

        try handle.close()

    }

}

#endif

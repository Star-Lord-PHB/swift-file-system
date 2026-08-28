#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingReadTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.StreamingReadTests.POSIXFifoTests {

    @Test
    func `Opening a FIFO with no writer does not wait`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try StreamingReadHandle(forFileAt: path)

        // With no writer connected a FIFO reads as end-of-file right away; the rendezvous
        // of a blocking FIFO open is deliberately not part of the streaming handles.
        #expect(try handle.read(length: 4).isEmpty)

        try handle.close()

    }


    // The open uses O_NONBLOCK only to keep the open itself from waiting; the I/O of the
    // handle must stay blocking.
    @Test
    func `Open restores blocking mode`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try StreamingReadHandle(forFileAt: path)

        let statusFlags = try handle.withUnsafeSystemHandle { systemHandle in
            let flags = fcntl(systemHandle.unsafeRawHandle, F_GETFL)
            try #require(flags >= 0)
            return flags
        }

        #expect(statusFlags & O_NONBLOCK == 0)

        try handle.close()

    }


    @Test
    func `Reads drain a FIFO and see EOF after the writer closes`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try StreamingReadHandle(forFileAt: path)

        // A plain blocking writer open succeeds right away because the reader is connected.
        let writerDescriptor = PlatformCLib.open(path.string, O_WRONLY)
        try #require(writerDescriptor >= 0)
        try #require("hello".withCString { write(writerDescriptor, $0, 5) } == 5)
        try #require(PlatformCLib.close(writerDescriptor) == 0)

        #expect(try handle.read(length: 3) == ByteBuffer("hel".utf8))
        #expect(try handle.read(length: 4) == ByteBuffer("lo".utf8))
        #expect(try handle.read(length: 2).isEmpty)

        try handle.close()

    }

}

#endif

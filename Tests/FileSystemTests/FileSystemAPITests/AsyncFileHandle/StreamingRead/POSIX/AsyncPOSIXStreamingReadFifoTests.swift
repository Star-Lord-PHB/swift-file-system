#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.StreamingReadTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The FIFO open contract (no waiting for a peer, blocking mode restored afterwards) and
// the end-of-file behavior are synchronous semantics; the tests below pin the routing of the
// async read to the sequential primitive on a real stream endpoint and add the shape that only
// exists with the executor: a read that has to wait for data and is completed by another task.
extension AsyncFileHandleAPITests.StreamingReadTests.POSIXFifoTests {

    @Test
    func `Opening a FIFO with no writer does not wait`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        // With no writer connected a FIFO reads as end-of-file right away.
        #expect(try await handle.read(length: 4).isEmpty)

        try await handle.close()

    }


    @Test
    func `Reads drain a FIFO and see EOF after the writer closes`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        // A plain blocking writer open succeeds right away because the reader is connected.
        let writerDescriptor = PlatformCLib.open(path.string, O_WRONLY)
        try #require(writerDescriptor >= 0)
        try #require("hello".withCString { write(writerDescriptor, $0, 5) } == 5)
        try #require(PlatformCLib.close(writerDescriptor) == 0)

        #expect(try await handle.read(length: 3) == ByteBuffer("hel".utf8))
        #expect(try await handle.read(length: 4) == ByteBuffer("lo".utf8))
        #expect(try await handle.read(length: 2).isEmpty)

        try await handle.close()

    }


    // The writer is connected before the read is issued, so the read has to wait for data
    // rather than reading end-of-file. Whether it is already parked on a pool thread when the
    // write lands is timing-dependent; the outcome is the same either way, and the point is
    // that the waiting read and the write completing it share the default executor.
    @Test(.timeLimit(.minutes(1)))
    func `A read waiting for data is completed by another task's write`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let reader = try await AsyncStreamingReadHandle(forFileAt: path)
        let writer = try await AsyncStreamingWriteHandle(forFileAt: path)

        let readerTask = Task {
            try await reader.read(length: 5)
        }

        #expect(try await writer.write(ByteBuffer("hello".utf8)) == 5)
        try await writer.close()

        #expect(try await readerTask.value == ByteBuffer("hello".utf8))

    }

}

#endif

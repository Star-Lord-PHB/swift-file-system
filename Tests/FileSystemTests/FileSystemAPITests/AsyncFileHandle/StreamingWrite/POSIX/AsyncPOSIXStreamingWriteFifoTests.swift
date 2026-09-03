#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.StreamingWriteTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The FIFO open and peer contracts are synchronous semantics; the tests below pin the
// error pass-through of the async open and the routing of the async write to the sequential
// primitive on a real stream endpoint (a positional write on a FIFO would fail instead).
extension AsyncFileHandleAPITests.StreamingWriteTests.POSIXFifoTests {

    // POSIX defines this open as failing with ENXIO instead of waiting for a reader.
    @Test
    func `Opening a FIFO with no reader reports peerUnavailable`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let error = await #expect(throws: PlatformError.self) {
            _ = try await AsyncStreamingWriteHandle(forFileAt: path)
        }

        #expect(error?.kind == .peerUnavailable)
        #expect(error?.systemCode == .noSuchDeviceOrAddress)

    }


    @Test
    func `Writes reach a FIFO reader`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let readerDescriptor = PlatformCLib.open(path.string, O_RDONLY | O_NONBLOCK)
        try #require(readerDescriptor >= 0)
        defer { _ = PlatformCLib.close(readerDescriptor) }

        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("hello".utf8)) == 5)

        var buffer = [UInt8](repeating: 0, count: 5)
        try #require(read(readerDescriptor, &buffer, 5) == 5)
        #expect(buffer == Array("hello".utf8))

        try await handle.close()

    }


    #if canImport(Darwin) || os(FreeBSD)
    // The open disables SIGPIPE for the descriptor, so a torn-down peer surfaces as an error
    // on the pool thread as well. Linux and OpenBSD have no per-descriptor equivalent: there
    // the same write raises SIGPIPE unless the process handles it, so this covers the Darwin
    // and FreeBSD contract only.
    @Test
    func `Writing to a FIFO after the reader closes reports brokenPipe`() async throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let readerDescriptor = PlatformCLib.open(path.string, O_RDONLY | O_NONBLOCK)
        try #require(readerDescriptor >= 0)

        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        try #require(PlatformCLib.close(readerDescriptor) == 0)

        let error = await #expect(throws: PlatformError.self) {
            try await handle.write(ByteBuffer("x".utf8))
        }

        #expect(error?.kind == .brokenPipe)
        #expect(error?.systemCode == .brokenPipe)

        // The non-Sendable handle was captured by the expectation closure above, so it cannot
        // be handed to a @concurrent close afterwards; deinit releases it.

    }
    #endif

}

#endif

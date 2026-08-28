#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingWriteTests {

    @Suite("POSIX FIFOs")
    struct POSIXFifoTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.StreamingWriteTests.POSIXFifoTests {

    // POSIX defines this open as failing with ENXIO instead of waiting for a reader.
    @Test
    func `Opening a FIFO with no reader reports peerUnavailable`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let error = #expect(throws: PlatformError.self) {
            _ = try StreamingWriteHandle(forFileAt: path)
        }

        #expect(error?.kind == .peerUnavailable)
        #expect(error?.systemCode == .noSuchDeviceOrAddress)

    }


    @Test
    func `Writes reach a FIFO reader`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let readerDescriptor = PlatformCLib.open(path.string, O_RDONLY | O_NONBLOCK)
        try #require(readerDescriptor >= 0)
        defer { _ = PlatformCLib.close(readerDescriptor) }

        let handle = try StreamingWriteHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("hello".utf8)) == 5)

        var buffer = [UInt8](repeating: 0, count: 5)
        try #require(read(readerDescriptor, &buffer, 5) == 5)
        #expect(buffer == Array("hello".utf8))

        try handle.close()

    }


    #if canImport(Darwin) || os(FreeBSD)
    // The open disables SIGPIPE for the descriptor, so a torn-down peer surfaces as an
    // error. Linux and OpenBSD have no per-descriptor equivalent: there the same write
    // raises SIGPIPE unless the process handles it, so this covers the Darwin and FreeBSD
    // contract only.
    @Test
    func `Writing to a FIFO after the reader closes reports brokenPipe`() throws {

        let path = workspace.path("fifo")
        try #require(mkfifo(path.string, 0o644) == 0)

        let readerDescriptor = PlatformCLib.open(path.string, O_RDONLY | O_NONBLOCK)
        try #require(readerDescriptor >= 0)

        let handle = try StreamingWriteHandle(forFileAt: path)

        try #require(PlatformCLib.close(readerDescriptor) == 0)

        let error = #expect(throws: PlatformError.self) {
            try handle.write(ByteBuffer("x".utf8))
        }

        #expect(error?.kind == .brokenPipe)
        #expect(error?.systemCode == .brokenPipe)

        try handle.close()

    }
    #endif

}

#endif

import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests {

    /// `UnsafeSystemHandle.pipe()`: the anonymous-pipe round trip and the platform semantics of
    /// its two ends. POSIX-only pipe facilities (poll, non-blocking reads) live in the POSIX
    /// suite. All reads happen after the data is written or the write end is closed, so no call
    /// here can block.
    @Suite("Pipe")
    struct PipeTests {}

}



extension UnsafeSystemHandleAPITests.PipeTests {

    @Test
    func `Write end data is readable from the read end`() throws {

        let handles = try UnsafeSystemHandle.pipe()
        let readHandle = handles.readHandle
        let writeHandle = handles.writeHandle

        let payload = Data("Hello pipe!".utf8)

        try #expect(writeHandle.write(contentsOf: payload.bytes) == 11)

        var buffer = Data(count: 11)

        try #expect(readHandle.read(into: buffer.mutableBytes) == 11)

        #expect(buffer == Data("Hello pipe!".utf8))

        try readHandle.close()
        try writeHandle.close()

    }


    @Test
    func `Pipe ends report the fifo kind`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        #expect(try handles.readHandle.type() == .fifo)
        #expect(try handles.writeHandle.type() == .fifo)

    }


    @Test
    func `Read end drains buffered data then reports EOF after the write end closes`() throws {

        let handles = try UnsafeSystemHandle.pipe()
        let readHandle = handles.readHandle
        let writeHandle = handles.writeHandle

        let payload = Data("bye".utf8)

        try writeHandle.write(contentsOf: payload.bytes)
        try writeHandle.close()

        var buffer = Data(count: 3)

        try #expect(readHandle.read(into: buffer.mutableBytes) == 3)

        #expect(buffer == Data("bye".utf8))

        // NOTE: Reading a drained pipe whose write end is closed is a platform difference at this
        // layer: POSIX read reports end-of-file as zero bytes, Windows ReadFile fails with
        // ERROR_BROKEN_PIPE.
        #if canImport(WinSDK)
        let error = #expect(throws: LowLevelError.self) {
            var drained = Data(count: 1)
            _ = try readHandle.read(into: drained.mutableBytes)
        }
        #expect(error?.systemCode == .brokenPipe)
        #else
        var drained = Data(count: 1)
        try #expect(readHandle.read(into: drained.mutableBytes) == 0)
        #endif

        try readHandle.close()

    }

}

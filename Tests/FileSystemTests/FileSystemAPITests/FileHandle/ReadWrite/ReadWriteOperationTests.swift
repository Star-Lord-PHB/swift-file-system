import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadWriteTests {

    @Test
    func `Sequential I/O shares the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let prefix = try handle.read(length: 3)
        let bytesWritten = try handle.write(ByteBuffer("ABC".utf8))
        let suffix = try handle.read(length: 2)

        #expect(prefix == ByteBuffer("012".utf8))
        #expect(bytesWritten == 3)
        #expect(suffix == ByteBuffer("67".utf8))
        #expect(try handle.currentOffset == 8)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("012ABC6789".utf8))

    }


    @Test
    func `Range selects where read bytes land in the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try #expect(handle.read(into: &buffer, at: 2 ..< 5) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(try handle.currentOffset == 3)

        try handle.close()

    }


    // NOTE: Range resolution, the consuming forwarding and the ByteBuffer bridging all live in the
    // shared `ReadFileHandleProtocol` extension and are covered once in the Read group. The two
    // tests below target the span primitive itself, which each handle type implements separately.

    @Test
    func `A span buffer is reusable across reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 3)

        do {
            var span = buffer.mutableBytes
            try #expect(handle.read(into: &span) == 3)
            try #expect(handle.read(into: &span) == 3)
        }

        #expect(buffer == ByteBuffer("def".utf8))
        #expect(try handle.currentOffset == 6)

        try handle.close()

    }


    @Test
    func `A consuming span buffer reads into the underlying storage`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 4)

        try #expect(handle.read(into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("abcd".utf8))

        try #expect(handle.read(fromOffset: 1, into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("bcde".utf8))
        #expect(try handle.currentOffset == 4)

        try handle.close()

    }


    @Test
    func `Positional I/O preserves the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)

        let bytesWritten = try handle.write(
            ByteBuffer("ABC".utf8),
            toOffset: 4
        )
        let positionalRead = try handle.read(fromOffset: 3, length: 5)

        #expect(bytesWritten == 3)
        #expect(positionalRead == ByteBuffer("3ABC7".utf8))
        #expect(try handle.currentOffset == 2)
        #expect(try handle.read(length: 2) == ByteBuffer("23".utf8))
        #expect(try handle.currentOffset == 4)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123ABC789".utf8))

    }


    @Test
    func `Negative positional read offset fails`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)

        let error = #expect(throws: PlatformError.self) {
            try handle.read(fromOffset: -1, length: 1)
        }

        #expect(error?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        try handle.close()

    }


    @Test
    func `Negative positional write offset fails`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)

        let error = #expect(throws: PlatformError.self) {
            try handle.write(ByteBuffer("x".utf8), toOffset: -1)
        }

        #expect(error?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123456789".utf8))

    }


    @Test
    func `Returned reads contain only available bytes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let partialBuffer = try handle.read(length: 5)
        let positionalBuffer = try handle.read(fromOffset: 2, length: 5)
        let eofBuffer = try handle.read(length: 2)

        #expect(partialBuffer == ByteBuffer("abc".utf8))
        #expect(positionalBuffer == ByteBuffer("c".utf8))
        #expect(eofBuffer.isEmpty)
        #expect(try handle.currentOffset == 3)

        try handle.close()

    }


    @Test
    func `Empty write preserves offset and contents`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)

        let bytesWritten = try handle.write(ByteBuffer())

        #expect(bytesWritten == 0)
        #expect(try handle.currentOffset == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

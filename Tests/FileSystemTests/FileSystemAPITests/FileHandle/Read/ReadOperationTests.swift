import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadTests {

    @Test
    func `Sequential reads advance the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)

        let first = try handle.read(length: 4)
        let second = try handle.read(length: 3)

        #expect(first == ByteBuffer("0123".utf8))
        #expect(second == ByteBuffer("456".utf8))
        #expect(try handle.currentOffset == 7)

        try handle.close()

    }


    @Test
    func `Range selects where read bytes land in the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try #expect(handle.read(into: &buffer, at: 2 ..< 5) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(try handle.currentOffset == 3)

        try handle.close()

    }


    @Test
    func `Open ended and empty ranges resolve against the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)

        var fromBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(into: &fromBuffer, at: 5...) == 3)

        #expect(fromBuffer == ByteBuffer([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x61, 0x62, 0x63]))

        var upToBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(into: &upToBuffer, at: ..<2) == 2)

        #expect(upToBuffer == ByteBuffer([0x64, 0x65, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))

        var emptyBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(into: &emptyBuffer, at: 3 ..< 3) == 0)

        #expect(emptyBuffer == ByteBuffer(repeating: 0xFF, count: 8))
        #expect(try handle.currentOffset == 5)

        try handle.close()

    }


    @Test
    func `File offset and buffer range are independent`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.seek(to: 2)
        var buffer = ByteBuffer(repeating: 0xFF, count: 8)

        try #expect(handle.read(fromOffset: 6, into: &buffer, at: 3 ..< 6) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0xFF, 0x36, 0x37, 0x38, 0xFF, 0xFF]))
        #expect(try handle.currentOffset == 2)

        try handle.close()

    }


    @Test
    func `A span buffer is reusable across reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
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
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 4)

        try #expect(handle.read(into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("abcd".utf8))

        try #expect(handle.read(fromOffset: 1, into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("bcde".utf8))
        #expect(try handle.currentOffset == 4)

        try handle.close()

    }


    @Test
    func `Positional reads preserve the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)
        var buffer = ByteBuffer(count: 3)

        try #expect(handle.read(fromOffset: 6, into: &buffer) == 3)
        let returnedBuffer = try handle.read(fromOffset: 3, length: 2)

        #expect(buffer == ByteBuffer("678".utf8))
        #expect(returnedBuffer == ByteBuffer("34".utf8))
        #expect(try handle.currentOffset == 2)

        try handle.close()

    }


    @Test
    func `Negative positional read offset fails`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)

        let error = #expect(throws: PlatformError.self) {
            try handle.read(fromOffset: -1, length: 1)
        }

        #expect(error?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        try handle.close()

    }


    @Test
    func `Returned buffer contains only bytes read`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try ReadFileHandle(forFileAt: path)

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
    func `Reads stop at EOF without advancing further`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.seek(to: 8)
        var partialBuffer = ByteBuffer(repeating: 0xFF, count: 5)

        try #expect(handle.read(into: &partialBuffer) == 2)

        #expect(partialBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))
        #expect(try handle.currentOffset == 10)

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        try #expect(handle.read(into: &eofBuffer) == 0)

        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(try handle.currentOffset == 10)

        try handle.close()

    }

}

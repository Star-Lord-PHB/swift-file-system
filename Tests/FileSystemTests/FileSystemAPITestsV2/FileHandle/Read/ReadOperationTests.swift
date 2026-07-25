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
    func `Length limits reads into a larger buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try handle.read(length: 3, into: &buffer)

        #expect(buffer == ByteBuffer([0x61, 0x62, 0x63, 0xFF, 0xFF, 0xFF]))
        #expect(try handle.currentOffset == 3)

        try handle.close()

    }


    @Test
    func `Buffer size limits a longer read`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(count: 3)

        try handle.read(length: 6, into: &buffer)

        #expect(buffer == ByteBuffer("abc".utf8))
        #expect(try handle.currentOffset == 3)

        try handle.close()

    }


    @Test
    func `Positional reads preserve the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.read(length: 2)
        var buffer = ByteBuffer(count: 3)

        try handle.read(fromOffset: 6, into: &buffer)
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

        try handle.read(into: &partialBuffer)

        #expect(partialBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))
        #expect(try handle.currentOffset == 10)

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        try handle.read(into: &eofBuffer)

        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(try handle.currentOffset == 10)

        try handle.close()

    }

}

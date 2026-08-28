import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadTests {

    @Test
    func `Reads land at their offsets without shared state`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)

        #expect(try handle.read(fromOffset: 0, length: 4) == ByteBuffer("0123".utf8))
        #expect(try handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try handle.read(fromOffset: 3, length: 2) == ByteBuffer("34".utf8))
        #expect(try handle.read(fromOffset: 3, length: 2) == ByteBuffer("34".utf8))

        try handle.close()

    }


    @Test
    func `Range selects where read bytes land in the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try #expect(handle.read(fromOffset: 0, into: &buffer, at: 2 ..< 5) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))

        try handle.close()

    }


    @Test
    func `Open ended and empty ranges resolve against the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)

        var fromBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(fromOffset: 0, into: &fromBuffer, at: 5...) == 3)

        #expect(fromBuffer == ByteBuffer([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x61, 0x62, 0x63]))

        var upToBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(fromOffset: 3, into: &upToBuffer, at: ..<2) == 2)

        #expect(upToBuffer == ByteBuffer([0x64, 0x65, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))

        var emptyBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        try #expect(handle.read(fromOffset: 0, into: &emptyBuffer, at: 3 ..< 3) == 0)

        #expect(emptyBuffer == ByteBuffer(repeating: 0xFF, count: 8))

        try handle.close()

    }


    @Test
    func `A span buffer is reusable across reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 3)

        do {
            var span = buffer.mutableBytes
            try #expect(handle.read(fromOffset: 0, into: &span) == 3)
            try #expect(handle.read(fromOffset: 3, into: &span) == 3)
        }

        #expect(buffer == ByteBuffer("def".utf8))

        try handle.close()

    }


    @Test
    func `A consuming span buffer reads into the underlying storage`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 4)

        try #expect(handle.read(fromOffset: 0, into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("abcd".utf8))

        try #expect(handle.read(fromOffset: 1, into: buffer.mutableBytes) == 4)

        #expect(buffer == ByteBuffer("bcde".utf8))

        try handle.close()

    }


    @Test
    func `Negative read offset fails`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.read(fromOffset: -1, length: 1)
        }

        #expect(error?.kind == .invalidInput)

        try handle.close()

    }


    @Test
    func `Returned buffer contains only bytes read`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try ReadFileHandle(forFileAt: path)

        #expect(try handle.read(fromOffset: 0, length: 5) == ByteBuffer("abc".utf8))
        #expect(try handle.read(fromOffset: 2, length: 5) == ByteBuffer("c".utf8))

        try handle.close()

    }


    @Test
    func `Reads at and past EOF return no bytes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var crossingBuffer = ByteBuffer(repeating: 0xFF, count: 5)

        try #expect(handle.read(fromOffset: 8, into: &crossingBuffer) == 2)

        #expect(crossingBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        try #expect(handle.read(fromOffset: 10, into: &eofBuffer) == 0)

        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(try handle.read(fromOffset: 20, length: 3).isEmpty)

        try handle.close()

    }

}

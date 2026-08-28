import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingReadTests {

    @Test
    func `Reads advance through the file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try StreamingReadHandle(forFileAt: path)

        #expect(try handle.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try handle.read(length: 3) == ByteBuffer("456".utf8))
        #expect(try handle.read(length: 3) == ByteBuffer("789".utf8))

        try handle.close()

    }


    @Test
    func `Range selects where read bytes land in the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try StreamingReadHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try #expect(handle.read(into: &buffer, at: 2 ..< 5) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(try handle.read(length: 3) == ByteBuffer("def".utf8))

        try handle.close()

    }


    @Test
    func `A span buffer is reusable across reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try StreamingReadHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 3)

        do {
            var span = buffer.mutableBytes
            try #expect(handle.read(into: &span) == 3)
            try #expect(handle.read(into: &span) == 3)
        }

        #expect(buffer == ByteBuffer("def".utf8))

        try handle.close()

    }


    @Test
    func `Reads stop at EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try StreamingReadHandle(forFileAt: path)

        #expect(try handle.read(length: 2) == ByteBuffer("ab".utf8))
        #expect(try handle.read(length: 5) == ByteBuffer("c".utf8))
        #expect(try handle.read(length: 2).isEmpty)
        #expect(try handle.read(length: 2).isEmpty)

        try handle.close()

    }

}

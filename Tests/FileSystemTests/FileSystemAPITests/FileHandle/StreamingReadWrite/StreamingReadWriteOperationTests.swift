import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingReadWriteTests {

    @Test
    func `Reads and writes share the file position`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try StreamingReadWriteHandle(forFileAt: path)

        #expect(try handle.read(length: 3) == ByteBuffer("012".utf8))
        #expect(try handle.write(ByteBuffer("ABC".utf8)) == 3)
        #expect(try handle.read(length: 2) == ByteBuffer("67".utf8))

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("012ABC6789".utf8))

    }


    @Test
    func `Reads stop at EOF and writes resume from there`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try StreamingReadWriteHandle(forFileAt: path)

        #expect(try handle.read(length: 5) == ByteBuffer("abc".utf8))
        #expect(try handle.read(length: 2).isEmpty)
        #expect(try handle.write(ByteBuffer("de".utf8)) == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abcde".utf8))

    }

}

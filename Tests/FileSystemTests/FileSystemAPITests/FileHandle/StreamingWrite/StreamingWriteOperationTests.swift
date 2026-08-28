import Testing
import SwiftFileSystem



extension FileHandleAPITests.StreamingWriteTests {

    @Test
    func `Writes advance through the file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try StreamingWriteHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("abc".utf8)) == 3)
        #expect(try handle.write(ByteBuffer("de".utf8)) == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abcde56789".utf8))

    }


    @Test
    func `Empty write leaves contents unchanged`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try StreamingWriteHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer()) == 0)
        #expect(try handle.write(ByteBuffer("X".utf8)) == 1)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("Xontents".utf8))

    }

}

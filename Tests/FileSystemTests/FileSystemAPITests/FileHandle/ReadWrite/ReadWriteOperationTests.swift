import Testing
import SwiftFileSystem



// NOTE: The buffer-range resolution, the span forwarding overloads and the error paths of the
// positional primitives live in the shared positional protocol extensions and are covered in
// the Read and Write groups; this group covers the interplay of both capabilities on one handle.
extension FileHandleAPITests.ReadWriteTests {

    @Test
    func `Positional reads observe positional writes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("ABC".utf8), toOffset: 4) == 3)
        #expect(try handle.read(fromOffset: 3, length: 5) == ByteBuffer("3ABC7".utf8))

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123ABC789".utf8))

    }


    @Test
    func `Reads and writes need no shared cursor`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        #expect(try handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try handle.write(ByteBuffer("ab".utf8), toOffset: 0) == 2)
        #expect(try handle.read(fromOffset: 0, length: 4) == ByteBuffer("ab23".utf8))
        #expect(try handle.write(ByteBuffer("Z".utf8), toOffset: 9) == 1)
        #expect(try handle.read(fromOffset: 8, length: 2) == ByteBuffer("8Z".utf8))

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("ab2345678Z".utf8))

    }


    @Test
    func `Writing past EOF creates a gap readable as zeros`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("z".utf8), toOffset: 5) == 1)
        #expect(try handle.read(fromOffset: 0, length: 8) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }

}

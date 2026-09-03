import Testing
import SwiftAsyncFileSystem



// NOTE: The buffer forms, the error paths and the cancellation contract of the positional
// primitives live in the shared async protocol extensions and are covered in the Read and
// Write groups; this group covers the interplay of both capabilities on one handle.
extension AsyncFileHandleAPITests.ReadWriteTests {

    @Test
    func `Positional reads observe positional writes`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("ABC".utf8), toOffset: 4) == 3)
        #expect(try await handle.read(fromOffset: 3, length: 5) == ByteBuffer("3ABC7".utf8))

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123ABC789".utf8))

    }


    @Test
    func `Reads and writes need no shared cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        #expect(try await handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try await handle.write(ByteBuffer("ab".utf8), toOffset: 0) == 2)
        #expect(try await handle.read(fromOffset: 0, length: 4) == ByteBuffer("ab23".utf8))
        #expect(try await handle.write(ByteBuffer("Z".utf8), toOffset: 9) == 1)
        #expect(try await handle.read(fromOffset: 8, length: 2) == ByteBuffer("8Z".utf8))

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("ab2345678Z".utf8))

    }


    @Test
    func `Writing past EOF creates a gap readable as zeros`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("z".utf8), toOffset: 5) == 1)
        #expect(try await handle.read(fromOffset: 0, length: 8) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }

}

import Testing
import SwiftAsyncFileSystem



// NOTE: The buffer forms and the cancellation contracts of the sequential primitives are
// covered in the StreamingRead and StreamingWrite groups; this group covers the shared file
// position of both capabilities on one handle.
extension AsyncFileHandleAPITests.StreamingReadWriteTests {

    @Test
    func `Reads and writes share the file position`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncStreamingReadWriteHandle(forFileAt: path)

        #expect(try await handle.read(length: 3) == ByteBuffer("012".utf8))
        #expect(try await handle.write(ByteBuffer("ABC".utf8)) == 3)
        #expect(try await handle.read(length: 2) == ByteBuffer("67".utf8))

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("012ABC6789".utf8))

    }


    @Test
    func `Reads stop at EOF and writes resume from there`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncStreamingReadWriteHandle(forFileAt: path)

        #expect(try await handle.read(length: 5) == ByteBuffer("abc".utf8))
        #expect(try await handle.read(length: 2).isEmpty)
        #expect(try await handle.write(ByteBuffer("de".utf8)) == 2)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abcde".utf8))

    }

}

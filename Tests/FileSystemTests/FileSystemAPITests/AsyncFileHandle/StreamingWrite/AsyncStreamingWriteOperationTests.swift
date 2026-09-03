import Testing
import SwiftAsyncFileSystem



// NOTE: The sequential write primitive is executor dispatch of the synchronous protocol
// extension; the tests below pin the routing to the sequential primitive, the async-side
// ByteBuffer overload and the cancellation contract.
extension AsyncFileHandleAPITests.StreamingWriteTests {

    @Test
    func `Writes advance through the file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("abc".utf8)) == 3)
        #expect(try await handle.write(ByteBuffer("de".utf8)) == 2)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abcde56789".utf8))

    }


    @Test
    func `Empty write leaves contents unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer()) == 0)
        #expect(try await handle.write(ByteBuffer("X".utf8)) == 1)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("Xontents".utf8))

    }


    @Test
    func `Pre-cancelled write reports cancellation without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.write(ByteBuffer("x".utf8))
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

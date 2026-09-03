import Testing
import SwiftAsyncFileSystem



// NOTE: The positional write primitive is executor dispatch of the synchronous protocol
// extension (offset handling is inherited); the tests below pin the routing to the positional
// primitive and the async-side ByteBuffer overload, plus the cancellation contract.
extension AsyncFileHandleAPITests.WriteTests {

    @Test
    func `Writes land at their offsets without shared state`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("abc".utf8), toOffset: 0) == 3)
        #expect(try await handle.write(ByteBuffer("XY".utf8), toOffset: 6) == 2)
        #expect(try await handle.write(ByteBuffer("z".utf8), toOffset: 4) == 1)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abc3z5XY89".utf8))

    }


    @Test
    func `Write extends the file past EOF`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("12345".utf8), toOffset: 0) == 5)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("12345".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer("z".utf8), toOffset: 5) == 1)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Negative write offset fails without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        let error = await #expect(throws: PlatformError.self) {
            try await handle.write(ByteBuffer("x".utf8), toOffset: -1)
        }

        #expect(error?.kind == .invalidInput)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123456789".utf8))

    }


    @Test
    func `Empty write leaves contents unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        #expect(try await handle.write(ByteBuffer(), toOffset: 0) == 0)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Pre-cancelled write reports cancellation without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.write(ByteBuffer("x".utf8), toOffset: 0)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.WriteTests {

    @Test
    func `Resize shrinks the file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        try await handle.resize(to: 4)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    @Test
    func `Resize grows the file with zero fill`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        try await handle.resize(to: 6)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0]))

    }


    @Test
    func `Negative resize fails without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        let error = await #expect(throws: PlatformError.self) {
            try await handle.resize(to: -1)
        }

        #expect(error?.kind == .invalidInput)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Synchronize succeeds after writing`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        _ = try await handle.write(ByteBuffer("contents".utf8), toOffset: 0)

        try await handle.synchronize()
        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Pre-cancelled resize reports cancellation without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.resize(to: 2)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Pre-cancelled synchronize reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.synchronize()
        }

    }

}

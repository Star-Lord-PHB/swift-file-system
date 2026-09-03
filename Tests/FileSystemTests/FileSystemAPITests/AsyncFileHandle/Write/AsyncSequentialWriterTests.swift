import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.WriteTests {

    @Suite("SequentialWriter")
    struct SequentialWriterTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }


        func capturedContents(at path: FilePath) throws -> ByteBuffer {
            ByteBuffer(try Data(contentsOf: URL(filePath: path.string)))
        }

    }

}



// NOTE: The view cursor engine is an async-side implementation of its own, so the synchronous
// view semantics are mirrored in full here. A handle a view was derived from cannot be
// consumed in the same scope afterwards, so these tests leave the release to deinit and
// capture contents while the handle is open; written data is visible to other opens right
// away on all platforms.
extension AsyncFileHandleAPITests.WriteTests.SequentialWriterTests {

    @Test
    func `Sequential writes advance the cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(writer.currentOffset == 0)
        #expect(try await writer.write(ByteBuffer("abc".utf8)) == 3)
        #expect(try await writer.write(ByteBuffer("de".utf8)) == 2)
        #expect(writer.currentOffset == 5)

        #expect(try capturedContents(at: path) == ByteBuffer("abcde56789".utf8))

    }


    @Test
    func `The handle stays usable while a writer is alive`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try await writer.write(ByteBuffer("ab".utf8)) == 2)
        #expect(try await handle.write(ByteBuffer("Z".utf8), toOffset: 9) == 1)
        #expect(try await writer.write(ByteBuffer("XY".utf8)) == 2)
        #expect(writer.currentOffset == 4)

        #expect(try capturedContents(at: path) == ByteBuffer("abXY45678Z".utf8))

    }


    @Test
    func `Seek supports beginning current and end origins`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try await writer.seek(to: 4, relativeTo: .beginning) == 4)
        #expect(try await writer.seek(to: 2, relativeTo: .current) == 6)
        #expect(try await writer.seek(to: -2, relativeTo: .end) == 8)
        #expect(try await writer.write(ByteBuffer("XY".utf8)) == 2)
        #expect(writer.currentOffset == 10)

        #expect(try capturedContents(at: path) == ByteBuffer("01234567XY".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try await writer.seek(to: 2, relativeTo: .end) == 5)
        #expect(try await writer.write(ByteBuffer("z".utf8)) == 1)
        #expect(writer.currentOffset == 6)

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Resize shrinks the file and preserves the cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        try await writer.seek(to: 8)

        try await writer.resize(to: 4)

        #expect(writer.currentOffset == 8)
        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    @Test
    func `Synchronize succeeds after sequential writes`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        _ = try await writer.write(ByteBuffer("contents".utf8))

        try await writer.synchronize()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    // NOTE: The full seek-rejection matrix for the view cursor lives in the SequentialReader
    // suite; all three views share the same cursor arithmetic through `trySeek`.

    @Test
    func `Seek rejects positions before file start`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        try await writer.seek(to: 2)

        let error = await #expect(throws: PlatformError.self) {
            try await writer.seek(to: -3, relativeTo: .current)
        }
        #expect(error?.kind == .invalidInput)
        #expect(writer.currentOffset == 2)

    }


    @Test
    func `Pre-cancelled write leaves the cursor and file unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        await Support.runPreCancelled {
            var writer = handle.sequentialWriter()

            let error = await #expect(throws: PlatformError.self) {
                try await writer.write(ByteBuffer("x".utf8))
            }

            Support.expectStandardCancellation(error)
            #expect(writer.currentOffset == 0)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

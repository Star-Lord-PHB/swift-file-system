import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.ReadWriteTests {

    @Suite("SequentialAccessor")
    struct SequentialAccessorTests {

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
extension AsyncFileHandleAPITests.ReadWriteTests.SequentialAccessorTests {

    @Test
    func `Sequential I/O shares the cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()

        #expect(try await accessor.read(length: 3) == ByteBuffer("012".utf8))
        #expect(try await accessor.write(ByteBuffer("ABC".utf8)) == 3)
        #expect(try await accessor.read(length: 2) == ByteBuffer("67".utf8))
        #expect(accessor.currentOffset == 8)

        #expect(try capturedContents(at: path) == ByteBuffer("012ABC6789".utf8))

    }


    @Test
    func `Seek controls sequential I/O`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()

        #expect(try await accessor.seek(to: 4, relativeTo: .beginning) == 4)
        #expect(try await accessor.read(length: 2) == ByteBuffer("45".utf8))
        #expect(try await accessor.seek(to: 1, relativeTo: .current) == 7)
        #expect(try await accessor.write(ByteBuffer("XY".utf8)) == 2)
        #expect(try await accessor.seek(to: -2, relativeTo: .end) == 8)
        #expect(try await accessor.read(length: 2) == ByteBuffer("Y9".utf8))
        #expect(accessor.currentOffset == 10)

        #expect(try capturedContents(at: path) == ByteBuffer("0123456XY9".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()

        #expect(try await accessor.seek(to: 2, relativeTo: .end) == 5)
        #expect(try await accessor.write(ByteBuffer("z".utf8)) == 1)
        #expect(accessor.currentOffset == 6)

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Reads stop at EOF and writes resume from there`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()

        #expect(try await accessor.read(length: 5) == ByteBuffer("abc".utf8))
        #expect(try await accessor.read(length: 2).isEmpty)
        #expect(accessor.currentOffset == 3)
        #expect(try await accessor.write(ByteBuffer("de".utf8)) == 2)
        #expect(accessor.currentOffset == 5)

        #expect(try capturedContents(at: path) == ByteBuffer("abcde".utf8))

    }


    @Test
    func `Resize shrinks the file and reads stop at the new EOF`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()
        #expect(try await accessor.read(length: 2) == ByteBuffer("01".utf8))

        try await accessor.resize(to: 4)

        #expect(accessor.currentOffset == 2)
        #expect(try await accessor.read(length: 4) == ByteBuffer("23".utf8))
        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    // NOTE: The full seek-rejection matrix for the view cursor lives in the SequentialReader
    // suite; all three views share the same cursor arithmetic through `trySeek`.

    @Test
    func `Seek rejects positions before file start`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        var accessor = handle.sequentialAccessor()
        try await accessor.seek(to: 2)

        let error = await #expect(throws: PlatformError.self) {
            try await accessor.seek(to: -11, relativeTo: .end)
        }
        #expect(error?.kind == .invalidInput)
        #expect(accessor.currentOffset == 2)

    }

}

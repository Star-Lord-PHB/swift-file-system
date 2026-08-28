import Foundation
import Testing
import SwiftFileSystem



extension FileHandleAPITests.WriteTests {

    @Suite("SequentialWriter")
    struct SequentialWriterTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }


        func capturedContents(at path: FilePath) throws -> ByteBuffer {
            ByteBuffer(try Data(contentsOf: URL(filePath: path.string)))
        }

    }

}



// NOTE: A handle a view was derived from cannot be consumed in the same scope afterwards, so
// these tests leave the release to deinit and capture contents while the handle is open;
// written data is visible to other opens right away on all platforms.
extension FileHandleAPITests.WriteTests.SequentialWriterTests {

    @Test
    func `Sequential writes advance the cursor`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(writer.currentOffset == 0)
        #expect(try writer.write(ByteBuffer("abc".utf8)) == 3)
        #expect(try writer.write(ByteBuffer("de".utf8)) == 2)
        #expect(writer.currentOffset == 5)

        #expect(try capturedContents(at: path) == ByteBuffer("abcde56789".utf8))

    }


    @Test
    func `The handle stays usable while a writer is alive`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try writer.write(ByteBuffer("ab".utf8)) == 2)
        #expect(try handle.write(ByteBuffer("Z".utf8), toOffset: 9) == 1)
        #expect(try writer.write(ByteBuffer("XY".utf8)) == 2)
        #expect(writer.currentOffset == 4)

        #expect(try capturedContents(at: path) == ByteBuffer("abXY45678Z".utf8))

    }


    @Test
    func `Seek supports beginning current and end origins`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try writer.seek(to: 4, relativeTo: .beginning) == 4)
        #expect(try writer.seek(to: 2, relativeTo: .current) == 6)
        #expect(try writer.seek(to: -2, relativeTo: .end) == 8)
        #expect(try writer.write(ByteBuffer("XY".utf8)) == 2)
        #expect(writer.currentOffset == 10)

        #expect(try capturedContents(at: path) == ByteBuffer("01234567XY".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()

        #expect(try writer.seek(to: 2, relativeTo: .end) == 5)
        #expect(try writer.write(ByteBuffer("z".utf8)) == 1)
        #expect(writer.currentOffset == 6)

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Resize shrinks the file and preserves the cursor`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        try writer.seek(to: 8)

        try writer.resize(to: 4)

        #expect(writer.currentOffset == 8)
        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    @Test
    func `Synchronize succeeds after sequential writes`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        _ = try writer.write(ByteBuffer("contents".utf8))

        try writer.synchronize()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    // NOTE: The full seek-rejection matrix for the view cursor lives in the SequentialReader
    // suite; all three views share the same cursor arithmetic through `trySeek`.

    @Test
    func `Seek rejects positions before file start`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        var writer = handle.sequentialWriter()
        try writer.seek(to: 2)

        let error = #expect(throws: PlatformError.self) {
            try writer.seek(to: -3, relativeTo: .current)
        }
        #expect(error?.kind == .invalidInput)
        #expect(writer.currentOffset == 2)

    }

}

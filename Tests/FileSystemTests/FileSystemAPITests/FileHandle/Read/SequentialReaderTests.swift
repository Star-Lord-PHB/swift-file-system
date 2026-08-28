import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadTests {

    @Suite("SequentialReader")
    struct SequentialReaderTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: A handle a view was derived from cannot be consumed in the same scope afterwards, so
// these tests leave the release to deinit; close-based release is pinned in the Lifecycle
// group.
extension FileHandleAPITests.ReadTests.SequentialReaderTests {

    @Test
    func `Sequential reads advance the cursor`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(reader.currentOffset == 0)
        #expect(try reader.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try reader.read(length: 3) == ByteBuffer("456".utf8))
        #expect(reader.currentOffset == 7)

    }


    @Test
    func `The handle stays usable while a reader is alive`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try reader.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try reader.read(length: 2) == ByteBuffer("45".utf8))

    }


    @Test
    func `Readers coexist with independent cursors`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var first = handle.sequentialReader()
        var second = handle.sequentialReader()

        #expect(try first.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try second.read(length: 2) == ByteBuffer("01".utf8))
        #expect(try first.read(length: 2) == ByteBuffer("45".utf8))
        #expect(first.currentOffset == 6)
        #expect(second.currentOffset == 2)

    }


    @Test
    func `A copied reader advances independently`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        _ = try reader.read(length: 4)

        var copy = reader

        #expect(try copy.read(length: 2) == ByteBuffer("45".utf8))
        #expect(try copy.read(length: 2) == ByteBuffer("67".utf8))
        #expect(reader.currentOffset == 4)
        #expect(try reader.read(length: 2) == ByteBuffer("45".utf8))

    }


    @Test
    func `Range selects where read bytes land in the buffer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        try #expect(reader.read(into: &buffer, at: 2 ..< 5) == 3)

        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(reader.currentOffset == 3)

    }


    @Test
    func `Seek supports beginning current and end origins`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try reader.seek(to: 4) == 4)
        #expect(reader.currentOffset == 4)
        #expect(try reader.seek(to: 2, relativeTo: .current) == 6)
        #expect(try reader.seek(to: -3, relativeTo: .end) == 7)
        #expect(try reader.read(length: 3) == ByteBuffer("789".utf8))
        #expect(reader.currentOffset == 10)

    }


    @Test
    func `Seek permits positions past EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try reader.seek(to: 3, relativeTo: .end) == 13)
        #expect(try reader.read(length: 2).isEmpty)
        #expect(reader.currentOffset == 13)

    }


    @Test
    func `Reads stop at EOF without advancing the cursor`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try reader.seek(to: 8)
        var partialBuffer = ByteBuffer(repeating: 0xFF, count: 5)

        try #expect(reader.read(into: &partialBuffer) == 2)

        #expect(partialBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))
        #expect(reader.currentOffset == 10)

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        try #expect(reader.read(into: &eofBuffer) == 0)

        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(reader.currentOffset == 10)

    }


    // NOTE: The cursor is view state, so the rejection kinds below are deterministic on every
    // platform.

    @Test
    func `Seek rejects positions before file start`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try reader.seek(to: 2)

        let beginningError = #expect(throws: PlatformError.self) {
            try reader.seek(to: -1, relativeTo: .beginning)
        }
        #expect(beginningError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

        let currentError = #expect(throws: PlatformError.self) {
            try reader.seek(to: -3, relativeTo: .current)
        }
        #expect(currentError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

        let endError = #expect(throws: PlatformError.self) {
            try reader.seek(to: -11, relativeTo: .end)
        }
        #expect(endError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

    }


    @Test
    func `Seek rejects arithmetic overflow`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try reader.seek(to: 1)

        let currentError = #expect(throws: PlatformError.self) {
            try reader.seek(to: Int64.max, relativeTo: .current)
        }
        #expect(currentError?.kind == .arithmeticOverflow)
        #expect(reader.currentOffset == 1)

        let endError = #expect(throws: PlatformError.self) {
            try reader.seek(to: Int64.max, relativeTo: .end)
        }
        #expect(endError?.kind == .arithmeticOverflow)
        #expect(reader.currentOffset == 1)

    }

}

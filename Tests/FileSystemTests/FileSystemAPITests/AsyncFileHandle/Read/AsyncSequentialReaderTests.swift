import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.ReadTests {

    @Suite("SequentialReader")
    struct SequentialReaderTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The view cursor engine (`AsyncPositionalHandleAccessor`) is an implementation of its
// own rather than executor dispatch of the synchronous accessor, so the synchronous view
// semantics are mirrored in full here. A handle a view was derived from cannot be consumed in
// the same scope afterwards, so these tests leave the release to deinit.
extension AsyncFileHandleAPITests.ReadTests.SequentialReaderTests {

    @Test
    func `Sequential reads advance the cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(reader.currentOffset == 0)
        #expect(try await reader.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try await reader.read(length: 3) == ByteBuffer("456".utf8))
        #expect(reader.currentOffset == 7)

    }


    @Test
    func `The handle stays usable while a reader is alive`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try await reader.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try await handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try await reader.read(length: 2) == ByteBuffer("45".utf8))

    }


    @Test
    func `Readers coexist with independent cursors`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var first = handle.sequentialReader()
        var second = handle.sequentialReader()

        #expect(try await first.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try await second.read(length: 2) == ByteBuffer("01".utf8))
        #expect(try await first.read(length: 2) == ByteBuffer("45".utf8))
        #expect(first.currentOffset == 6)
        #expect(second.currentOffset == 2)

    }


    @Test
    func `A copied reader advances independently`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        _ = try await reader.read(length: 4)

        var copy = reader

        #expect(try await copy.read(length: 2) == ByteBuffer("45".utf8))
        #expect(try await copy.read(length: 2) == ByteBuffer("67".utf8))
        #expect(reader.currentOffset == 4)
        #expect(try await reader.read(length: 2) == ByteBuffer("45".utf8))

    }


    @Test
    func `Range selects where read bytes land in the buffer`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        let bytesRead = try await reader.read(into: &buffer, at: 2 ..< 5)

        #expect(bytesRead == 3)
        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(reader.currentOffset == 3)

    }


    @Test
    func `Seek supports beginning current and end origins`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try await reader.seek(to: 4) == 4)
        #expect(reader.currentOffset == 4)
        #expect(try await reader.seek(to: 2, relativeTo: .current) == 6)
        #expect(try await reader.seek(to: -3, relativeTo: .end) == 7)
        #expect(try await reader.read(length: 3) == ByteBuffer("789".utf8))
        #expect(reader.currentOffset == 10)

    }


    @Test
    func `Seek permits positions past EOF`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()

        #expect(try await reader.seek(to: 3, relativeTo: .end) == 13)
        #expect(try await reader.read(length: 2).isEmpty)
        #expect(reader.currentOffset == 13)

    }


    @Test
    func `Reads stop at EOF without advancing the cursor`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try await reader.seek(to: 8)
        var partialBuffer = ByteBuffer(repeating: 0xFF, count: 5)

        let partialCount = try await reader.read(into: &partialBuffer)

        #expect(partialCount == 2)
        #expect(partialBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))
        #expect(reader.currentOffset == 10)

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        let eofCount = try await reader.read(into: &eofBuffer)

        #expect(eofCount == 0)
        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(reader.currentOffset == 10)

    }


    // NOTE: The cursor is view state, so the rejection kinds below are deterministic on every
    // platform.

    @Test
    func `Seek rejects positions before file start`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try await reader.seek(to: 2)

        let beginningError = await #expect(throws: PlatformError.self) {
            try await reader.seek(to: -1, relativeTo: .beginning)
        }
        #expect(beginningError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

        let currentError = await #expect(throws: PlatformError.self) {
            try await reader.seek(to: -3, relativeTo: .current)
        }
        #expect(currentError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

        let endError = await #expect(throws: PlatformError.self) {
            try await reader.seek(to: -11, relativeTo: .end)
        }
        #expect(endError?.kind == .invalidInput)
        #expect(reader.currentOffset == 2)

    }


    @Test
    func `Seek rejects arithmetic overflow`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var reader = handle.sequentialReader()
        try await reader.seek(to: 1)

        let currentError = await #expect(throws: PlatformError.self) {
            try await reader.seek(to: Int64.max, relativeTo: .current)
        }
        #expect(currentError?.kind == .arithmeticOverflow)
        #expect(reader.currentOffset == 1)

        let endError = await #expect(throws: PlatformError.self) {
            try await reader.seek(to: Int64.max, relativeTo: .end)
        }
        #expect(endError?.kind == .arithmeticOverflow)
        #expect(reader.currentOffset == 1)

    }


    // The cursor lives in the view and is only advanced once the executor has reported the
    // transfer, so an operation that never ran leaves it where it was. The view only exists
    // inside the pre-cancelled task, hence the assertions are made there.

    @Test
    func `Pre-cancelled read leaves the cursor unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.runPreCancelled {
            var reader = handle.sequentialReader()

            let error = await #expect(throws: PlatformError.self) {
                try await reader.read(length: 4)
            }

            Support.expectStandardCancellation(error)
            #expect(reader.currentOffset == 0)
        }

    }


    @Test
    func `Pre-cancelled end-relative seek leaves the cursor unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.runPreCancelled {
            var reader = handle.sequentialReader()

            let error = await #expect(throws: PlatformError.self) {
                try await reader.seek(to: -1, relativeTo: .end)
            }

            Support.expectStandardCancellation(error)
            #expect(reader.currentOffset == 0)
        }

    }

}

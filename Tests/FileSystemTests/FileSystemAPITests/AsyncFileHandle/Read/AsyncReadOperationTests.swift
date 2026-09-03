import Testing
import SwiftAsyncFileSystem



// NOTE: The positional read primitive is executor dispatch of the synchronous protocol
// extension (offset handling and EOF alignment are inherited); the buffer convenience
// overloads are async-side copies, so their forms are covered in full here for the positional
// family.
extension AsyncFileHandleAPITests.ReadTests {

    @Test
    func `Reads land at their offsets without shared state`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        #expect(try await handle.read(fromOffset: 0, length: 4) == ByteBuffer("0123".utf8))
        #expect(try await handle.read(fromOffset: 6, length: 4) == ByteBuffer("6789".utf8))
        #expect(try await handle.read(fromOffset: 3, length: 2) == ByteBuffer("34".utf8))
        #expect(try await handle.read(fromOffset: 3, length: 2) == ByteBuffer("34".utf8))

        try await handle.close()

    }


    @Test
    func `Range selects where read bytes land in the buffer`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        let bytesRead = try await handle.read(fromOffset: 0, into: &buffer, at: 2 ..< 5)

        #expect(bytesRead == 3)
        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))

        try await handle.close()

    }


    @Test
    func `Open ended and empty ranges resolve against the buffer`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        var fromBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        let fromCount = try await handle.read(fromOffset: 0, into: &fromBuffer, at: 5...)

        #expect(fromCount == 3)
        #expect(fromBuffer == ByteBuffer([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x61, 0x62, 0x63]))

        var upToBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        let upToCount = try await handle.read(fromOffset: 3, into: &upToBuffer, at: ..<2)

        #expect(upToCount == 2)
        #expect(upToBuffer == ByteBuffer([0x64, 0x65, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))

        var emptyBuffer = ByteBuffer(repeating: 0xFF, count: 8)
        let emptyCount = try await handle.read(fromOffset: 0, into: &emptyBuffer, at: 3 ..< 3)

        #expect(emptyCount == 0)
        #expect(emptyBuffer == ByteBuffer(repeating: 0xFF, count: 8))

        try await handle.close()

    }


    @Test
    func `A span buffer is reusable across reads`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 3)

        do {
            var span = buffer.mutableBytes
            let firstCount = try await handle.read(fromOffset: 0, into: &span)
            let secondCount = try await handle.read(fromOffset: 3, into: &span)
            #expect(firstCount == 3)
            #expect(secondCount == 3)
        }

        #expect(buffer == ByteBuffer("def".utf8))

        try await handle.close()

    }


    @Test
    func `A consuming span buffer reads into the underlying storage`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 4)

        let firstCount = try await handle.read(fromOffset: 0, into: buffer.mutableBytes)

        #expect(firstCount == 4)
        #expect(buffer == ByteBuffer("abcd".utf8))

        let secondCount = try await handle.read(fromOffset: 1, into: buffer.mutableBytes)

        #expect(secondCount == 4)
        #expect(buffer == ByteBuffer("bcde".utf8))

        try await handle.close()

    }


    @Test
    func `Negative read offset fails`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        let error = await #expect(throws: PlatformError.self) {
            try await handle.read(fromOffset: -1, length: 1)
        }

        #expect(error?.kind == .invalidInput)

        try await handle.close()

    }


    @Test
    func `Returned buffer contains only bytes read`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        #expect(try await handle.read(fromOffset: 0, length: 5) == ByteBuffer("abc".utf8))
        #expect(try await handle.read(fromOffset: 2, length: 5) == ByteBuffer("c".utf8))

        try await handle.close()

    }


    @Test
    func `Reads at and past EOF return no bytes`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        var crossingBuffer = ByteBuffer(repeating: 0xFF, count: 5)

        let crossingCount = try await handle.read(fromOffset: 8, into: &crossingBuffer)

        #expect(crossingCount == 2)
        #expect(crossingBuffer == ByteBuffer([0x38, 0x39, 0xFF, 0xFF, 0xFF]))

        var eofBuffer = ByteBuffer(repeating: 0xFF, count: 3)
        let eofCount = try await handle.read(fromOffset: 10, into: &eofBuffer)

        #expect(eofCount == 0)
        #expect(eofBuffer == ByteBuffer(repeating: 0xFF, count: 3))
        #expect(try await handle.read(fromOffset: 20, length: 3).isEmpty)

        try await handle.close()

    }


    @Test
    func `Pre-cancelled read reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.read(fromOffset: 0, length: 8)
        }

    }

}

import Testing
import SwiftAsyncFileSystem



// NOTE: The sequential read primitive is executor dispatch of the synchronous protocol
// extension (EOF and Windows pipe alignment are inherited); the tests below pin the routing to
// the sequential primitive, the async-side buffer overload copies and the cancellation
// contract. The handle is not Sendable: the pre-cancelled test moves it into the task through
// the `sending` closure.
extension AsyncFileHandleAPITests.StreamingReadTests {

    @Test
    func `Reads advance through the file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        #expect(try await handle.read(length: 4) == ByteBuffer("0123".utf8))
        #expect(try await handle.read(length: 3) == ByteBuffer("456".utf8))
        #expect(try await handle.read(length: 3) == ByteBuffer("789".utf8))

        try await handle.close()

    }


    @Test
    func `Range selects where read bytes land in the buffer`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 6)

        let bytesRead = try await handle.read(into: &buffer, at: 2 ..< 5)

        #expect(bytesRead == 3)
        #expect(buffer == ByteBuffer([0xFF, 0xFF, 0x61, 0x62, 0x63, 0xFF]))
        #expect(try await handle.read(length: 3) == ByteBuffer("def".utf8))

        try await handle.close()

    }


    @Test
    func `A span buffer is reusable across reads`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abcdef")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)
        var buffer = ByteBuffer(repeating: 0xFF, count: 3)

        do {
            var span = buffer.mutableBytes
            let firstCount = try await handle.read(into: &span)
            let secondCount = try await handle.read(into: &span)
            #expect(firstCount == 3)
            #expect(secondCount == 3)
        }

        #expect(buffer == ByteBuffer("def".utf8))

        try await handle.close()

    }


    @Test
    func `Reads stop at EOF`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        #expect(try await handle.read(length: 2) == ByteBuffer("ab".utf8))
        #expect(try await handle.read(length: 5) == ByteBuffer("c".utf8))
        #expect(try await handle.read(length: 2).isEmpty)
        #expect(try await handle.read(length: 2).isEmpty)

        try await handle.close()

    }


    @Test
    func `Pre-cancelled read reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.read(length: 8)
        }

    }

}

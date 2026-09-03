import Testing
import SwiftAsyncFileSystem



// NOTE: `AsyncAppendHandle.append` is an implementation of its own (a plain write on the
// O_APPEND descriptor on POSIX, the end-of-file OVERLAPPED sentinel on Windows) rather than
// executor dispatch of the synchronous append, so the native append semantics are mirrored
// here instead of being inherited.
extension AsyncFileHandleAPITests.AppendTests {

    @Test
    func `Multiple handles append at file end`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "initial")
        let firstHandle = try await AsyncAppendHandle(forFileAt: path)
        let secondHandle = try await AsyncAppendHandle(forFileAt: path)

        #expect(try await firstHandle.append(ByteBuffer(" first".utf8)) == 6)
        #expect(try await secondHandle.append(ByteBuffer(" second".utf8)) == 7)
        #expect(try await firstHandle.append(ByteBuffer(" third".utf8)) == 6)

        try await firstHandle.close()
        try await secondHandle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("initial first second third".utf8))

    }


    @Test
    func `No-follow truncate open appends at file end`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "existing contents")
        let handle = try await AsyncAppendHandle(
            forFileAt: path,
            options: .editFile(truncate: true, noFollow: true)
        )

        #expect(try await handle.append(ByteBuffer("one".utf8)) == 3)

        let otherHandle = try await AsyncAppendHandle(forFileAt: path)
        #expect(try await otherHandle.append(ByteBuffer(" two".utf8)) == 4)
        try await otherHandle.close()

        #expect(try await handle.append(ByteBuffer(" three".utf8)) == 6)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("one two three".utf8))

    }


    @Test
    func `Empty append leaves contents unchanged`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        #expect(try await handle.append(ByteBuffer()) == 0)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Synchronize succeeds after appending`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        _ = try await handle.append(ByteBuffer("contents".utf8))
        try await handle.synchronize()
        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Pre-cancelled append reports cancellation without changing file`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.append(ByteBuffer("x".utf8))
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

import Testing
import SwiftFileSystem



extension FileHandleAPITests.WriteTests {

    @Test
    func `Sequential writes advance the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)

        let firstCount = try handle.write(ByteBuffer("abc".utf8))
        let secondCount = try handle.write(ByteBuffer("de".utf8))

        #expect(firstCount == 3)
        #expect(secondCount == 2)
        #expect(try handle.currentOffset == 5)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abcde56789".utf8))

    }


    @Test
    func `Write extends file past EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)

        let bytesWritten = try handle.write(ByteBuffer("12345".utf8))

        #expect(bytesWritten == 5)
        #expect(try handle.currentOffset == 5)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("12345".utf8))

    }


    @Test
    func `Positional writes preserve the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        _ = try handle.write(ByteBuffer("ab".utf8))

        let bytesWritten = try handle.write(
            ByteBuffer("XYZ".utf8),
            toOffset: 6
        )

        #expect(bytesWritten == 3)
        #expect(try handle.currentOffset == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("ab2345XYZ9".utf8))

    }


    @Test
    func `Negative positional write offset fails`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        _ = try handle.write(ByteBuffer("ab".utf8))

        let error = #expect(throws: PlatformError.self) {
            try handle.write(ByteBuffer("x".utf8), toOffset: -1)
        }

        #expect(error?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("ab23456789".utf8))

    }


    @Test
    func `Empty write leaves offset and contents unchanged`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try WriteFileHandle(forFileAt: path)

        let bytesWritten = try handle.write(ByteBuffer())

        #expect(bytesWritten == 0)
        #expect(try handle.currentOffset == 0)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }
}

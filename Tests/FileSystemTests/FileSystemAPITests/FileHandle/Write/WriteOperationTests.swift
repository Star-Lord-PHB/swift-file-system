import Testing
import SwiftFileSystem



extension FileHandleAPITests.WriteTests {

    @Test
    func `Writes land at their offsets without shared state`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("abc".utf8), toOffset: 0) == 3)
        #expect(try handle.write(ByteBuffer("XY".utf8), toOffset: 6) == 2)
        #expect(try handle.write(ByteBuffer("z".utf8), toOffset: 4) == 1)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("abc3z5XY89".utf8))

    }


    @Test
    func `Write extends the file past EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("12345".utf8), toOffset: 0) == 5)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("12345".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer("z".utf8), toOffset: 5) == 1)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Negative write offset fails without changing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.write(ByteBuffer("x".utf8), toOffset: -1)
        }

        #expect(error?.kind == .invalidInput)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123456789".utf8))

    }


    @Test
    func `Empty write leaves contents unchanged`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.write(ByteBuffer(), toOffset: 0) == 0)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

import Testing
import SwiftFileSystem



extension FileHandleAPITests.WriteTests {

    @Test
    func `Resize shrinks the file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)

        try handle.resize(to: 4)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    @Test
    func `Resize grows the file with zero fill`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)

        try handle.resize(to: 6)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0]))

    }


    @Test
    func `Negative resize fails without changing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try WriteFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.resize(to: -1)
        }

        #expect(error?.kind == .invalidInput)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Synchronize succeeds after writing`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try WriteFileHandle(forFileAt: path)
        _ = try handle.write(ByteBuffer("contents".utf8), toOffset: 0)

        try handle.synchronize()
        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

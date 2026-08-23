import Foundation
import Testing
import SwiftFileSystem
import SwiftFileSystemFoundationCompat



extension FileHandleAPITests.AppendTests {

    @Test
    func `Multiple handles append at file end`() throws {

        let path = try workspace.makeFile(at: "file", contents: "initial")
        let firstHandle = try AppendHandle(forFileAt: path)
        let secondHandle = try AppendHandle(forFileAt: path)

        #expect(try firstHandle.append(ByteBuffer(" first".utf8)) == 6)
        #expect(try secondHandle.append(ByteBuffer(" second".utf8)) == 7)
        #expect(try firstHandle.append(ByteBuffer(" third".utf8)) == 6)

        try firstHandle.close()
        try secondHandle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("initial first second third".utf8))

    }


    @Test
    func `Contiguous bytes can be appended`() throws {

        let path = try workspace.makeFile(at: "file", contents: "initial")
        let handle = try AppendHandle(forFileAt: path)
        let data = Data(" appended".utf8)

        #expect(try handle.append(data) == 9)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("initial appended".utf8))

    }


    @Test
    func `Synchronize succeeds after appending`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try AppendHandle(forFileAt: path)

        _ = try handle.append(ByteBuffer("contents".utf8))
        try handle.synchronize()
        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}

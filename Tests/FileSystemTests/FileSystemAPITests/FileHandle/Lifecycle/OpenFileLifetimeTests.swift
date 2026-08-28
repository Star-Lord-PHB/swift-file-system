import Foundation
import Testing
import SwiftFileSystem



extension FileHandleAPITests.LifecycleTests {

    @Test
    func `Closing one handle leaves another to the same file usable`() throws {

        let path = try workspace.makeFile(at: "file", contents: "shared contents")
        let firstHandle = try ReadFileHandle(forFileAt: path)
        let secondHandle = try ReadFileHandle(forFileAt: path)

        try firstHandle.close()

        #expect(try secondHandle.read(fromOffset: 0, length: 6) == ByteBuffer("shared".utf8))

        try secondHandle.close()

    }


    @Test
    func `Open handle outlives file removal`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try FileManager.default.removeItem(atPath: path.string)

        try #require(!FileManager.default.fileExists(atPath: path.string))
        #expect(try handle.read(fromOffset: 0, length: 8) == ByteBuffer("contents".utf8))
        #expect(try handle.write(ByteBuffer(" linger".utf8), toOffset: 8) == 7)
        #expect(try handle.read(fromOffset: 0, length: 15) == ByteBuffer("contents linger".utf8))

        try handle.close()

    }


    @Test
    func `Open handle outlives file rename`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let movedPath = workspace.path("moved")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try FileManager.default.moveItem(atPath: path.string, toPath: movedPath.string)

        try #require(!FileManager.default.fileExists(atPath: path.string))
        #expect(try handle.read(fromOffset: 0, length: 8) == ByteBuffer("contents".utf8))
        #expect(try handle.write(ByteBuffer(" moved".utf8), toOffset: 8) == 6)

        try handle.close()

        #expect(try capturedContents(at: movedPath) == ByteBuffer("contents moved".utf8))

    }

}

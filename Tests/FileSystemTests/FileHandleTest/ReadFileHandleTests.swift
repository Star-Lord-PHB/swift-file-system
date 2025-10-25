import Testing
import SystemPackage
import Foundation
@testable import FileSystem


extension FileSystemTest {

    final class ReadFileHandleTests: FileSystemTest {}

}



extension FileSystemTest.ReadFileHandleTests {

    @Test("Read Handle")
    func readHandle() async throws {
        
        let content = Data("Hello, World!".utf8)
        let path = try makeFile(at: "test.txt", contents: content)

        try await expectNoResHandleLeak {

            let readHandle = try ReadFileHandle(forFileAt: path)

            let info = try readHandle.fileInfo()
            #expect(try FileInfo(fileAt: path) == info)

            let buffer1 = try readHandle.read(length: 5)
            #expect(buffer1.data == content.prefix(5))

            let currentOffset = try readHandle.seek(to: -1, relativeTo: .current)
            #expect(currentOffset == (5 - 1))

            let buffer2 = try readHandle.read(length: 5)
            #expect(buffer2.data == content.dropFirst(4).prefix(5))

            var buffer3 = ByteBuffer(count: content.count - 1)
            try readHandle.read(fromOffset: 1, into: &buffer3)
            #expect(buffer3.data == content.dropFirst(1))

            try #expect(readHandle.currentOffset == (5 - 1 + 5))

            try readHandle.seek(to: -1, relativeTo: .end)
            #expect(try readHandle.currentOffset == Int64(content.count - 1))

            try readHandle.close()

        } preheat: {
            _ = try FileInfo(fileAt: path)
        }

    }


    @Test("Read Handle (Error: Not Exist)")
    func readHandleErrorNotExist() async throws {

        let path = makePath(at: "test.txt")

        let error = try #require(throws: FileError.self) {
            _ = try ReadFileHandle(forFileAt: path)
        }
        let errorCode = try #require(error.code)

        #if canImport(WinSDK)
        #expect(errorCode == .fileNotFound)
        #else
        #expect(errorCode == .noSuchFileOrDirectory)
        #endif

    }


    @Test("Read Handle (Error: Unsupported)")
    func readHandleErrorUnsupported() async throws {

        let path = try makeDir(at: "dir")

        let handle = try ReadFileHandle(forFileAt: path)

        let error = try #require(throws: FileError.self) {
            try handle.read(length: 10)
        }
        let errorCode = try #require(error.code)

        #if canImport(WinSDK)
        #expect(errorCode == .invalidFunction)
        #else
        #expect(errorCode == .isADirectory)
        #endif

    }

}
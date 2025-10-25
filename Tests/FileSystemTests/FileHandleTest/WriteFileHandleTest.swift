import Testing
import SystemPackage
import Foundation
@testable import FileSystem


extension FileSystemTest {

    final class WriteFileHandleTests: FileSystemTest {}

}



extension FileSystemTest.WriteFileHandleTests {


    @Test("Write Handle (Existing File)")
    func writeHandleExisting() async throws {
        
        let content = Data("Hello, World!".utf8)
        let path = try makeFile(at: "test.txt")

        try await expectNoResHandleLeak {

            let writeHandle = try WriteFileHandle(forFileAt: path, options: .editFile())

            let info = try writeHandle.fileInfo()
            #expect(try FileInfo(fileAt: path) == info)

            let bytesWritten1 = try writeHandle.write(content.prefix(5))
            #expect(bytesWritten1 == 5)

            #expect(try writeHandle.currentOffset == 5)

            let bytesWritten2 = try writeHandle.write(content.dropFirst(5))
            #expect(bytesWritten2 == 8)

            #expect(try writeHandle.currentOffset == 13)

            #expect(try writeHandle.seek(to: 6, relativeTo: .beginning) == 6)
            #expect(try writeHandle.currentOffset == 6)

            let bytesWritten3 = try writeHandle.write(Data("Swift".utf8), toOffset: 7)
            #expect(bytesWritten3 == 5)

            #expect(try writeHandle.currentOffset == 6)

            try writeHandle.resize(to: 12)

            try writeHandle.synchronize()
            try writeHandle.close()

        } preheat: {
            _ = try FileInfo(fileAt: path)
        }

        let finalContent = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
        #expect(finalContent == "Hello, Swift")

    }


    @Test("Write Handle (Truncate File)")
    func writeHandleTruncate() async throws {
        
        let content = Data("Hello, Swift!".utf8)
        let path = try makeFile(at: "test.txt", contents: Data("Hello, World!".utf8))

        try await expectNoResHandleLeak {

            let writeHandle = try WriteFileHandle(forFileAt: path, options: .editFile(truncate: true))

            let bytesWritten = try writeHandle.write(content)
            #expect(bytesWritten == content.count)

            try writeHandle.synchronize()
            try writeHandle.close()

        }

        let finalContent = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
        #expect(finalContent == "Hello, Swift!")

    }


    @Test("Write Handle (Create File)")
    func writeHandleCreate() async throws {

        let content = Data("Hello, Swift!".utf8)
        let path = makePath(at: "test.txt")

        try await expectNoResHandleLeak {

            let writeHandle = try WriteFileHandle(forFileAt: path, options: .newFile())

            let bytesWritten = try writeHandle.write(content)
            #expect(bytesWritten == content.count)

            try writeHandle.synchronize()
            try writeHandle.close()
            
        }

        let finalContent = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
        #expect(finalContent == "Hello, Swift!")

    }


    @Test("Write Handle (Error: Already Exist)")
    func writeHandleErrorAlreadyExist() async throws {

        let path = try makeFile(at: "test.txt")

        let error = try #require(throws: FileError.self) {
            _ = try WriteFileHandle(forFileAt: path, options: .newFile(replaceExisting: false))
        }
        let errorCode = try #require(error.code)

        #expect(errorCode == .fileExists)

    }


    @Test("Write Handle (Error: Not Exist)")
    func writeHandleErrorNotExist() async throws {

        let path = makePath(at: "test.txt")

        let error = try #require(throws: FileError.self) {
            _ = try WriteFileHandle(forFileAt: path, options: .editFile(createIfMissing: false))
        }
        let errorCode = try #require(error.code)

        #if canImport(WinSDK)
        #expect(errorCode == .fileNotFound)
        #else
        #expect(errorCode == .noSuchFileOrDirectory)
        #endif
    }

}
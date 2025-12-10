import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class CreateDirectoryTest: FileSystemTest {}

}



extension FileSystemTest.CreateDirectoryTest {

    @Test("Dst Not Exist, no intermediate")
    func createDirDstNotExistNoIntermediate() async throws {
        
        let path = makePath(at: "dir")
        
        try FileSystem().createDirectory(at: path)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .directory)

    }


    @Test("Intermediate Not Exist, no intermediate")
    func createDirIntermediateNotExistNoIntermediate() async throws {
        
        let path = makePath(at: "dir/a")

        let error = #expect(throws: FileError.self) {
            try FileSystem().createDirectory(at: path, withIntermediateDirectories: false)
        }

        #if canImport(WinSDK)
        #expect(error.reason == .fileNotFound)
        #else
        #expect(error?.code == .noSuchFileOrDirectory)
        #endif

    }


    @Test("Dst Exist, no intermediate")
    func createDirDstExistNoIntermediate() async throws {
        
        let path = try makeDir(at: "dir")

        let error = #expect(throws: FileError.self) {
            try FileSystem().createDirectory(at: path, withIntermediateDirectories: false)
        }

        #if canImport(WinSDK)
        #expect(error.reason == .alreadyExists)
        #else
        #expect(error?.code == .fileExists)
        #endif

    }


    @Test("Dst Not Exist, with intermediate")
    func createDirDstNotExistWithIntermediate() async throws {
        
        let path = makePath(at: "dir")
        
        try FileSystem().createDirectory(at: path, withIntermediateDirectories: true)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .directory)

    }


    @Test("Intermediate Not Exist, with intermediate")
    func createDirIntermediateNotExistWithIntermediate() async throws {
        
        let path = makePath(at: "dir/a/b/c")
        
        try FileSystem().createDirectory(at: path, withIntermediateDirectories: true)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .directory)

    }


    @Test("Dst Exist, with intermediate")
    func createDirDstExistWithIntermediate() async throws {
        
        let path = try makeDir(at: "dir")
        let prevInfo = try FileInfo(fileAt: path)

        try FileSystem().createDirectory(at: path, withIntermediateDirectories: true)

        let info = try FileInfo(fileAt: path)

        #expect(info == prevInfo)

    }

}
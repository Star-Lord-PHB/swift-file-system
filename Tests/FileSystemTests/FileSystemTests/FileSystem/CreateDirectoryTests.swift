import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    final class CreateDirectoryTest: FSIsolatedTestCase {}

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

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().createDirectory(at: path, withIntermediateDirectories: false)
        }

        #expect(error?.kind == .notFound)

    }


    @Test("Dst Exist, no intermediate")
    func createDirDstExistNoIntermediate() async throws {
        
        let path = try makeDir(at: "dir")

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().createDirectory(at: path, withIntermediateDirectories: false)
        }

        #expect(error?.kind == .alreadyExists)

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
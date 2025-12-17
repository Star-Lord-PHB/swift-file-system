import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class CreateHardLinkTest: FileSystemTest {

        func expectIdentical(path1: FilePath, path2: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws {

            #if canImport(WinSDK)

            #warning("Not implemented")
            fatalError("Not implemented")

            #else 

            var stat1 = stat()
            var stat2 = stat()

            try #require(lstat(path1.string, &stat1) == 0, sourceLocation: sourceLocation)
            try #require(lstat(path2.string, &stat2) == 0, sourceLocation: sourceLocation)

            #expect(stat1.st_ino == stat2.st_ino, sourceLocation: sourceLocation)

            #endif 

        }

    }

}



extension FileSystemTest.CreateHardLinkTest {

    @Test("Hard Link Existing File")
    func hardLinkExistingFile() async throws {
        
        let existingPath = try makeFile(at: "file", contents: .init("Hello, World!".utf8))
        let hardLinkParh = makePath(at: "link")

        try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)

        try expectIdentical(path1: existingPath, path2: hardLinkParh)

    }


    @Test("Hard Link Existing Symlink")
    func hardLinkExistingSymlink() async throws {
        
        let existingPath = try makeSymlink(at: "symlink", pointingTo: "target")
        let hardLinkParh = makePath(at: "link")

        try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)

        try expectIdentical(path1: existingPath, path2: hardLinkParh)

    }


    @Test("Hard Link Existing Directory")
    func hardLinkExistingDirectory() async throws {
        
        let existingPath = try makeDir(at: "directory")
        let hardLinkParh = makePath(at: "link")

        let error = #expect(throws: FileError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #if canImport(WinSDK)
        // TODO: Add error expectation
        #else
        #expect(error?.code == .platform(.operationNotPermitted))
        #endif

    }


    @Test("Hard Link Non-Existing Item")
    func hardLinkNonExistingItem() async throws {
        
        let existingPath = makePath(at: "non-existing")
        let hardLinkParh = makePath(at: "link")

        let error = #expect(throws: FileError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #expect(error?.code == .fileNotFound)

    }


    @Test("Hard Link Item Already Exists")
    func hardLinkItemAlreadyExists() async throws {
        
        let existingPath = try makeFile(at: "file", contents: .init("Hello, World!".utf8))
        let hardLinkParh = try makeFile(at: "link", contents: .init("Existing File".utf8))

        let error = #expect(throws: FileError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #expect(error?.code == .fileExists)

    }

}
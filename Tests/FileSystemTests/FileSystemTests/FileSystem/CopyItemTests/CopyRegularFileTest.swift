import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest.CopyFileTest {

    @Test("File -> Empty Dst")
    func copyFileToEmptyDst() async throws {
        
        let content = Data("Serika is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        let dstPath = makePath(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try await Task.sleep(nanoseconds: 200_000_000)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy())

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> File Dst (.overwrite)")
    func copyFileToFileDstOverwrite() async throws {
        
        let content = Data("Serika is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        try await Task.sleep(nanoseconds: 200_000_000)
        let dstPath = try makeFile(at: "dst.txt", contents: Data())

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .overwrite))

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> File Dst (.error)")
    func copyFileToFileDstError() async throws {
        
        let content = Data("Serika is Cute!".utf8)
        let contentDst = Data("Hoshino is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        let dstPath = try makeFile(at: "dst.txt", contents: contentDst)

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: PlatformError.self) {
            try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .error), errorStrategy: .abortOnError)
        }

        #expect(error.kind == .alreadyExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> File Dst (.skip)")
    func copyFileToFileDstSkip() async throws {
        
        let content = Data("Serika is Cute!".utf8)
        let contentDst = Data("Hoshino is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        try await Task.sleep(nanoseconds: 200_000_000)
        let dstPath = try makeFile(at: "dst.txt", contents: contentDst)
        
        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .skip))

        // since the copy is skipped due to file exists, the dst file should remain unchanged
        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> Dir Dst (.overwrite)")
    func copyFileToDirDstOverwrite() async throws {
        
        let srcPath = try makeFile(at: "src.txt")
        let dstPath = try makeDir(at: "dstDir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: PlatformError.self) {
            // Copying a file to a directory is not supported
            try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .overwrite), errorStrategy: .abortOnError)
        }

        #expect(error.kind == .isADirectory)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> Dir Dst (.skip)")
    func copyFileToDirDstSkip() async throws {

        let srcPath = try makeFile(at: "src.txt")
        let dstPath = try makeDir(at: "dstDir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .skip))

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> Dir Dst (.error)")
    func copyFileToDirDstError() async throws {
        
        let srcPath = try makeFile(at: "src.txt")
        let dstPath = try makeDir(at: "dstDir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: PlatformError.self) {
            try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .error), errorStrategy: .abortOnError)
        }

        #expect(error.kind == .alreadyExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> Symlink Dst (.overwrite)")
    func copyFileToSymlinkDstOverwrite() async throws {
        
        let content = Data("Serika is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        try await Task.sleep(nanoseconds: 200_000_000)
        let dstTargetPath = try makeFile(at: "linkTarget.txt", contents: Data())
        let dstPath = try makeSymlink(at: "dst.txt", pointingTo: dstTargetPath)

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .overwrite))

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File -> Symlink Dst (.error)")
    func copyFileToSymlinkDstError() async throws {

        let content = Data("Serika is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        let dstTargetPath = try makeFile(at: "linkTarget.txt", contents: Data())
        let dstPath = try makeSymlink(at: "dst.txt", pointingTo: dstTargetPath)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: dstTargetPath)

        let error = try #require(throws: PlatformError.self) {
            try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .error), errorStrategy: .abortOnError)
        }

        #expect(error.kind == .alreadyExists)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: dstTargetPath, toMatch: expectation2)

    }


    @Test("File -> Symlink Dst (.skip)")
    func copyFileToSymlinkDstSkip() async throws {

        let content = Data("Serika is Cute!".utf8)

        let srcPath = try makeFile(at: "src.txt", contents: content)
        let dstTargetPath = try makeFile(at: "linkTarget.txt", contents: Data())
        let dstPath = try makeSymlink(at: "dst.txt", pointingTo: dstTargetPath)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: dstTargetPath)

        try FileSystem().copyItem(at: srcPath, to: dstPath, options: .legacy(existingTarget: .skip))

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: dstTargetPath, toMatch: expectation2)

    }

}
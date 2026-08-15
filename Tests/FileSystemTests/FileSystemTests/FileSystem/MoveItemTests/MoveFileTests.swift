import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest.MoveItemTest {

    @Test("File -> Empty Dst")
    func moveFileToEmptyDst() async throws {
        
        let srcPath = try makeFile(at: "src")
        let dstPath = makePath(at: "dst")

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("File -> File Dst (.overwrite)")
    func moveFileToFileDstOverwrite() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeFile(at: "dst", contents: .init("Hoshino is Cute!".utf8))

        let expectation = try ItemExpectation.from(itemAt: srcPath, excluding: replacedItemExclusions)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("File -> File Dst (.skip)")
    func moveFileToFileDstSkip() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeFile(at: "dst", contents: .init("Hoshino is Cute!".utf8))

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> File Dst (.error)")
    func moveFileToFileDstError() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeFile(at: "dst", contents: .init("Hoshino is Cute!".utf8))

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> Symlink Dst (.overwrite)")
    func moveFileToSymlinkDstOverwrite() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let targetPath = try makeFile(at: "target", contents: .init("Hoshino is Cute!".utf8))
        let dstPath = try makeSymlink(at: "dst", pointingTo: targetPath)

        let expectation = try ItemExpectation.from(itemAt: srcPath, excluding: replacedItemExclusions)

        try FileSystem().moveItem(at: srcPath, to: dstPath)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("File -> Symlink Dst (.skip)")
    func moveFileToSymlinkDstSkip() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let targetPath = try makeFile(at: "target", contents: .init("Hoshino is Cute!".utf8))
        let dstPath = try makeSymlink(at: "dst", pointingTo: targetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> Symlink Dst (.error)")
    func moveFileToSymlinkDstError() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let targetPath = try makeFile(at: "target", contents: .init("Hoshino is Cute!".utf8))
        let dstPath = try makeSymlink(at: "dst", pointingTo: targetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> Dir Dst (.overwrite)")
    func moveFileToDirDst() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath)
        }

        #expect(error?.kind.maybe(.isADirectory) == true)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> Dir Dst (.skip)")
    func moveFileToDirDstSkip() async throws {
        
        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("File -> Dir Dst (.error)")
    func moveFileToDirDstError() async throws {

        let srcPath = try makeFile(at: "src", contents: .init("Serika is Cute!".utf8))
        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }

}
import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.MoveItemTest {

    @Test("Symlink -> Empty Dst")
    func moveSymlinkToEmptyDst() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstPath = makePath(at: "dstLink")

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("Symlink -> File Dst (.overwrite)")
    func moveSymlinkToFileDstOverwrite() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("Symlink -> File Dst (.skip)")
    func moveSymlinkToFileDstSkip() async throws {

        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> File Dst (.error)")
    func moveSymlinkToFileDstError() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> Symlink Dst (.overwrite)")
    func moveSymlinkToSymlinkDstOverwrite() async throws {

        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let expectation = try ItemExpectation.from(itemAt: srcPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)

        try expectItem(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)
        
    }


    @Test("Symlink -> Symlink Dst (.skip)")
    func moveSymlinkToSymlinkDstSkip() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> Symlink Dst (.error)")
    func moveSymlinkToSymlinkDstError() async throws {

        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> Dir Dst (.overwrite)")
    func moveSymlinkToDirDstOverwrite() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #expect(error?.code == .isADirectory)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> Dir Dst (.skip)")
    func moveSymlinkToDirDstSkip() async throws {
        
        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Symlink -> Dir Dst (.error)")
    func moveSymlinkToDirDstError() async throws {

        let srcTargetPath = try makeFile(at: "srcTarget")
        let srcPath = try makeSymlink(at: "srcLink", pointingTo: srcTargetPath)

        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try ItemExpectation.from(itemAt: srcPath)
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)

        try expectItem(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }

}
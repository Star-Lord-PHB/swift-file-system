import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



// MARK: Copy symlink itself
extension FileSystemTest.CopyFileTest {

    @Test("Symlink -> Empty Dst")
    func copySymlinkToEmptyDst() async throws {
        
        // let targetPath = try makeFile(at: "target.txt")
        let targetPath = makePath(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)

        let dstPath = makePath(at: "dst.lnk")

        let expectation = try ItemExpectation.from(itemAt: linkPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Symlink -> File Dst (.overwrite)")
    func copySymlinkToFileDstOverwrite() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: linkPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Symlink -> File Dst (.skip)")
    func copySymlinkToFileDstSkip() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Symlink -> File Dst (.error)")
    func copySymlinkToFileDstError() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyLink)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Symlink -> Symlink Dst (.overwrite)")
    func copySymlinkToSymlinkDstOverwrite() async throws {

        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation = try ItemExpectation.from(itemAt: linkPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation)
        
    }


    @Test("Symlink -> Symlink Dst (.skip)")
    func copySymlinkToSymlinkDstSkip() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: targetPath2)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: targetPath2, toMatch: expectation2)

    }


    @Test("Symlink -> Symlink Dst (.error)")
    func copySymlinkToSymlinkDstError() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: targetPath2)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyLink)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: targetPath2, toMatch: expectation2)

    }


    @Test("Symlink -> Dir Dst (.overwrite)")
    func copySymlinkToDirDstOverwrite() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyLink)
        }

        #expect(error.code == .isADirectory)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Symlink -> Dir Dst (.skip)")
    func copySymlinkToDirDstSkip() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyLink)

        try expectItem(at: dstPath, toMatch: expectation)
    }


    @Test("Symlink -> Dir Dst (.error)")
    func copySymlinkToDirDstError() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyLink)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }

}



// MARK: Copy target of a symlink where the target is a regular file 
extension FileSystemTest.CopyFileTest {

    @Test("File Symlink -> Empty Dst")
    func copySymlinkTargetToEmptyDst() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)

        let dstPath = makePath(at: "dst.lnk")

        let expectation = try ItemExpectation.from(itemAt: targetPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> File Dst (.overwrite)")
    func copySymlinkTargetToFileDstOverwrite() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: targetPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> File Dst (.skip)")
    func copySymlinkTargetToFileDstSkip() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> File Dst (.error)")
    func copySymlinkTargetToFileDstError() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)
        let dstPath = try makeFile(at: "dst.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyTarget)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> Symlink Dst (.overwrite)")
    func copySymlinkTargetToSymlinkDstOverwrite() async throws {

        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation = try ItemExpectation.from(itemAt: targetPath1)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation)
        
    }


    @Test("File Symlink -> Symlink Dst (.skip)")
    func copySymlinkTargetToSymlinkDstSkip() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: targetPath2)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: targetPath2, toMatch: expectation2)

    }


    @Test("File Symlink -> Symlink Dst (.error)")
    func copySymlinkTargetToSymlinkDstError() async throws {

        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let targetPath2 = try makeFile(at: "target2.txt")
        let dstPath = try makeSymlink(at: "dst.lnk", pointingTo: targetPath2)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: targetPath2)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyTarget)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: targetPath2, toMatch: expectation2)

    }


    @Test("File Symlink -> Dir Dst (.overwrite)")
    func copySymlinkTargetToDirDstOverwrite() async throws {
        
        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .overwrite, symlinkOption: .copyTarget)
        }

        #expect(error.code == .isADirectory)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> Dir Dst (.skip)")
    func copySymlinkTargetToDirDstSkip() async throws {

        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .skip, symlinkOption: .copyTarget)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("File Symlink -> Dir Dst (.error)")
    func copySymlinkTargetToDirDstError() async throws {

        let targetPath1 = try makeFile(at: "target1.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath1)
        let dstPath = try makeDir(at: "dir")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: linkPath, to: dstPath, onExistingTarget: .error, symlinkOption: .copyTarget)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }

}



// MARK: Copy target of a symlink where the target is a regular file
extension FileSystemTest.CopyFileTest {

    @Test("Dir Symlink -> Empty Dst")
    func copyDirSymlinkToEmptyDst() async throws {

        let structure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
            "link1": .symlink(target: "file1.txt"),
            "a": [
                "file2.txt": .file(contents: "Hoshino is Cute!"),
                "link2": .symlink(target: "../file1.txt"),
                "b": [
                    "file3.txt": .file(contents: "Hello Swift!")
                ]
            ]
        ] as FileStructure
        
        let targetPath = try makeFileStructure(at: "srcDir", structure: structure)
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: targetPath)

        let dstPath = makePath(at: "dst")

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: targetPath), 
            contents: [
                "file1.txt": .item(expectation: try .from(itemAt: targetPath.appending("file1.txt"))),
                "link1": .item(expectation: try .from(itemAt: targetPath.appending("link1"))),
                "a": .dir(
                    expectation: .from(itemAt: targetPath.appending("a")), 
                    contents: [
                        "file2.txt": .item(expectation: try .from(itemAt: targetPath.appending("a/file2.txt"))),
                        "link2": .item(expectation: try .from(itemAt: targetPath.appending("a/link2"))),
                        "b": .dir(
                            expectation: .from(itemAt: targetPath.appending("a/b")), 
                            contents: [
                                "file3.txt": .item(expectation: try .from(itemAt: targetPath.appending("a/b/file3.txt")))
                            ]
                        )
                    ]
                )
            ]
        )

        try FileSystem().copyItem(at: linkPath, to: dstPath, symlinkOption: .copyTarget)

        try expectFileStructure(at: dstPath, toMatch: expectation)

    }

}
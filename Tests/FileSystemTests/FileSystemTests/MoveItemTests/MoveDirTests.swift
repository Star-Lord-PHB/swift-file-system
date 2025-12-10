import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.MoveItemTest {

    fileprivate var templateStructure: FileStructure {
        [
            "file1": .file(contents: "Serika is Cute!"),
            "a": [
                "file2": .file(contents: "Hoshino is Cuate!"),
                "link1": .symlink(target: "../file1")
            ]
        ]
    }

    fileprivate var templateStructure2: FileStructure {
        [
            "file3": .file(contents: "Hello Swift!"),
            "link2": .symlink(target: "file3")
        ]
    }


    @Test("Dir -> Empty Dst")
    func moveDirToEmptyDst() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = makePath(at: "dstDir")

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )


        try FileSystem().moveItem(at: srcPath, to: dstPath)

        try expectFileStructure(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("Dir -> File Dst (.overwrite)")
    func moveDirToFileDstOverwrite() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)

        let dstPath = try makeFile(at: "dstFile")

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .accessDenied)
        #else
        #expect(error?.code == .notADirectory)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> File Dst (.skip)")
    func moveDirToFileDstSkip() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)

        let dstPath = try makeFile(at: "dstFile")

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> File Dst (.error)")
    func moveDirToFileDstError() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)

        let dstPath = try makeFile(at: "dstFile")

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .alreadyExists)
        #else
        #expect(error?.code == .fileExists)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Symlink Dst (.overwrite)")
    func moveDirToSymlinkDstOverwrite() async throws {
        
        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .accessDenied)
        #else
        #expect(error?.code == .notADirectory)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Symlink Dst (.skip)")
    func moveDirToSymlinkDstSkip() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Symlink Dst (.error)")
    func moveDirToSymlinkDstError() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)

        let dstTargetPath = try makeFile(at: "dstTarget")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: dstTargetPath)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try ItemExpectation.from(itemAt: dstPath)

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .alreadyExists)
        #else
        #expect(error?.code == .fileExists)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectItem(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Empty Dir Dst (.overwrite)")
    func moveDirToEmptyDirDstOverwrite() async throws {
        
        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeDir(at: "dstDir")

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)

        try expectFileStructure(at: dstPath, toMatch: expectation)
        #expect(FileManager.default.fileExists(atPath: srcPath.string) == false)

    }


    @Test("Dir -> Empty Dir Dst (.skip)")
    func moveDirToEmptyDirDstSkip() async throws {
        
        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstPath), 
            contents: [:]
        )

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectFileStructure(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Empty Dir Dst (.error)")
    func moveDirToEmptyDirDstError() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeDir(at: "dstDir")

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstPath), 
            contents: [:]
        )

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .alreadyExists)
        #else
        #expect(error?.code == .fileExists)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectFileStructure(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Dir Dst (.overwrite)")
    func moveDirToDirDstOverwrite() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeFileStructure(at: "dstDir", structure: templateStructure2)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstPath), 
            contents: [
                "file3": .item(expectation: .from(itemAt: dstPath.appending("file3"))),
                "link2": .item(expectation: .from(itemAt: dstPath.appending("link2")))
            ]
        )

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .accessDenied)
        #else
        #expect(error?.code == .directoryNotEmpty)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectFileStructure(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Dir Dst (.skip)")
    func moveDirToDirDstSkip() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeFileStructure(at: "dstDir", structure: templateStructure2)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstPath), 
            contents: [
                "file3": .item(expectation: .from(itemAt: dstPath.appending("file3"))),
                "link2": .item(expectation: .from(itemAt: dstPath.appending("link2")))
            ]
        )

        try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .skip)

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectFileStructure(at: dstPath, toMatch: dstExpectation)

    }


    @Test("Dir -> Dir Dst (.error)")
    func moveDirToDirDstError() async throws {

        let srcPath = try makeFileStructure(at: "srcDir", structure: templateStructure)
        let dstPath = try makeFileStructure(at: "dstDir", structure: templateStructure2)

        let srcExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcPath), 
            contents: [
                "file1": .item(expectation: .from(itemAt: srcPath.appending("file1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcPath.appending("a")), 
                    contents: [
                        "file2": .item(expectation: .from(itemAt: srcPath.appending("a/file2"))),
                        "link1": .item(expectation: .from(itemAt: srcPath.appending("a/link1")))
                    ]
                )
            ]
        )
        let dstExpectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstPath), 
            contents: [
                "file3": .item(expectation: .from(itemAt: dstPath.appending("file3"))),
                "link2": .item(expectation: .from(itemAt: dstPath.appending("link2")))
            ]
        )

        let error = #expect(throws: FileError.self) {
            try FileSystem().moveItem(at: srcPath, to: dstPath, onExistingTarget: .error)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .alreadyExists)
        #else
        #expect(error?.code == .fileExists)
        #endif

        try expectFileStructure(at: srcPath, toMatch: srcExpectation)
        try expectFileStructure(at: dstPath, toMatch: dstExpectation)

    }

}
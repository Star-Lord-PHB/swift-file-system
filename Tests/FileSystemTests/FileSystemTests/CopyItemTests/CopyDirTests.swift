import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.CopyFileTest {

    @Test("Dir -> Empty Dst")
    func copyDirToEmptyDst() async throws {
        
        let structure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
            "link1": .symlink(target: "./file1.txt"),
            "a": [
                "file2.txt": .file(contents: "Hoshino is Cute!"),
                "link2": .symlink(target: "../file1.txt"),
            ],
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: structure)
        let dstPath = makePath(at: "dstDir")

        let expectation  = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcDirPath), 
            contents: [
                "file1.txt": .item(expectation: .from(itemAt: srcDirPath.appending("file1.txt"))),
                "link1": .item(expectation: .from(itemAt: srcDirPath.appending("link1"))),
                "a": .dir(
                    expectation: .from(itemAt: srcDirPath.appending("a")),
                    contents: [
                        "file2.txt": .item(expectation: .from(itemAt: srcDirPath.appending("a/file2.txt"))),
                        "link2": .item(expectation: .from(itemAt: srcDirPath.appending("a/link2"))),
                    ]
                )
            ]
        )

        try FileSystem().copyItem(at: srcDirPath, to: dstPath)

        try expectFileStructure(at: dstPath, toMatch: expectation)

    }


    @Test("Dir -> Dir Dst (.overwrite)")
    func copyDirToDirDstOverwrite() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
            "link1": .symlink(target: "./file1.txt"),
            "a": [
                "file2.txt": .file(contents: "Hoshino is Cute!"),
                "link2": .symlink(target: "../file1.txt"),
            ],
        ] as FileStructure

        let dstStructure = [
            "file1.txt": .file(contents: "Old Content"),                        // overwritten
            "oldFile.txt": .file(contents: "This file should remain."),         // remain
            "a": [                                                              // overwritten
                "file2.txt": .file(contents: "Old Content"),                    // overwritten
                "link2": .symlink(target: "../oldFile.txt"),                    // overwritten
            ],
            "b": [                                                              // remain (on Windows, its access time and permission may be changed)
                "extra.txt": .file(contents: "This directory should remain."),
            ]
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        try await Task.sleep(nanoseconds: 100_000_000)
        let dstDirPath = try makeFileStructure(at: "dstDir", structure: dstStructure)

        #if canImport(WinSDK)
        let dirBExpectationExcludingSetting = [.fileTimes] as ExpectationCriterias
        #else
        let dirBExpectationExcludingSetting = [] as ExpectationCriterias
        #endif

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: srcDirPath),
            contents: [
                "file1.txt": .item(expectation: .from(itemAt: srcDirPath.appending("file1.txt"))),
                "link1": .item(expectation: .from(itemAt: srcDirPath.appending("link1"))),
                "oldFile.txt": .item(expectation: .from(itemAt: dstDirPath.appending("oldFile.txt"))),
                "a": .dir(
                    expectation: .from(itemAt: srcDirPath.appending("a")),
                    contents: [
                        "file2.txt": .item(expectation: .from(itemAt: srcDirPath.appending("a/file2.txt"))),
                        "link2": .item(expectation: .from(itemAt: srcDirPath.appending("a/link2"))),
                    ]
                ),
                "b": .dir(
                    expectation: .from(itemAt: dstDirPath.appending("b"), excluding: dirBExpectationExcludingSetting), 
                    contents: [
                        "extra.txt": .item(expectation: .from(itemAt: dstDirPath.appending("b/extra.txt"))),
                    ]
                )
            ]
        )

        try FileSystem().copyItem(at: srcDirPath, to: dstDirPath, onExistingTarget: .overwrite)

        try expectFileStructure(at: dstDirPath, toMatch: expectation)

    }


    @Test("Dir -> Dir Dst (.skip)")
    func copyDirToDirDstSkip() async throws {

        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
            "link1": .symlink(target: "./file1.txt"),
            "a": [
                "file2.txt": .file(contents: "Hoshino is Cute!"),
                "link2": .symlink(target: "../file1.txt"),
                "file3.txt": .file(contents: "This file should not be copied."),
            ],
        ] as FileStructure

        let dstStructure = [
            "file1.txt": .file(contents: "Old Content"),                        // remain
            "oldFile.txt": .file(contents: "This file should remain."),         // remain
            "a": [                                                              // remain
                "file2.txt": .file(contents: "Old Content"),                    // remain
                "link2": .symlink(target: "../oldFile.txt"),                    // remain
            ],
            "b": [
                "extra.txt": .file(contents: "This directory should remain."),
            ]
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        try await Task.sleep(nanoseconds: 100_000_000)
        let dstDirPath = try makeFileStructure(at: "dstDir", structure: dstStructure)

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstDirPath, excluding: [.modificationTime, .accessTime]),
            contents: [
                "file1.txt": .item(expectation: .from(itemAt: dstDirPath.appending("file1.txt"))),
                "link1": .item(expectation: .from(itemAt: srcDirPath.appending("link1"))),
                "oldFile.txt": .item(expectation: .from(itemAt: dstDirPath.appending("oldFile.txt"))),
                "a": .dir(
                    expectation: .from(itemAt: dstDirPath.appending("a"), excluding: [.modificationTime, .accessTime]),
                    contents: [
                        "file2.txt": .item(expectation: .from(itemAt: dstDirPath.appending("a/file2.txt"))),
                        "file3.txt": .item(expectation: .from(itemAt: srcDirPath.appending("a/file3.txt"))),
                        "link2": .item(expectation: .from(itemAt: dstDirPath.appending("a/link2"))),
                    ]
                ),
                "b": .dir(
                    expectation: .from(itemAt: dstDirPath.appending("b")), 
                    contents: [
                        "extra.txt": .item(expectation: .from(itemAt: dstDirPath.appending("b/extra.txt"))),
                    ]
                )
            ]
        )

        try FileSystem().copyItem(at: srcDirPath, to: dstDirPath, onExistingTarget: .skip)

        try expectFileStructure(at: dstDirPath, toMatch: expectation)

    }


    @Test("Dir -> Dir Dst (.error)")
    func copyDirToDirDstError() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let dstStructure = [
            "file2.txt": .file(contents: "Old Content"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let dstDirPath = try makeFileStructure(at: "dstDir", structure: dstStructure)

        let expectation = try FileStructureExpectation.dir(
            expectation: .from(itemAt: dstDirPath),
            contents: [
                "file2.txt": .item(expectation: .from(itemAt: dstDirPath.appending("file2.txt"))),
            ]
        )

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: srcDirPath, to: dstDirPath, onExistingTarget: .error)
        }

        #expect(error.code == .fileExists)

        try expectFileStructure(at: dstDirPath, toMatch: expectation)

    }


    @Test("Dir -> File Dst (.overwrite)")
    func copyDirToFileDstOverwrite() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let dstPath = try makeFile(at: "dstFile.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #expect(error.code == .notADirectory)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Dir -> File Dst (.skip)")
    func copyDirToFileDstSkip() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let dstPath = try makeFile(at: "dstFile.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Dir -> File Dst (.error)")
    func copyDirToFileDstError() async throws {

        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let dstPath = try makeFile(at: "dstFile.txt")

        let expectation = try ItemExpectation.from(itemAt: dstPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation)

    }


    @Test("Dir -> Symlink Dst (.overwrite)")
    func copyDirToSymlinkDstOverwrite() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let linkTargetPath = try makeFile(at: "target.txt")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: linkTargetPath)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: linkTargetPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .overwrite)
        }

        #expect(error.code == .notADirectory)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: linkTargetPath, toMatch: expectation2)

    }


    @Test("Dir -> Symlink Dst (.skip)")
    func copyDirToSymlinkDstSkip() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let linkTargetPath = try makeFile(at: "target.txt")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: linkTargetPath)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: linkTargetPath)

        try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .skip)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: linkTargetPath, toMatch: expectation2)

    }


    @Test("Dir -> Symlink Dst (.error)")
    func copyDirToSymlinkDstError() async throws {
        
        let srcStructure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
        ] as FileStructure

        let srcDirPath = try makeFileStructure(at: "srcDir", structure: srcStructure)
        let linkTargetPath = try makeFile(at: "target.txt")
        let dstPath = try makeSymlink(at: "dstLink", pointingTo: linkTargetPath)

        let expectation1 = try ItemExpectation.from(itemAt: dstPath)
        let expectation2 = try ItemExpectation.from(itemAt: linkTargetPath)

        let error = try #require(throws: FileError.self) {
            try FileSystem().copyItem(at: srcDirPath, to: dstPath, onExistingTarget: .error)
        }

        #expect(error.code == .fileExists)

        try expectItem(at: dstPath, toMatch: expectation1)
        try expectItem(at: linkTargetPath, toMatch: expectation2)

    }

}
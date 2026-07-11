import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    final class RemoveItemTest: FSIsolatedTestCase {}

}



extension FileSystemTest.RemoveItemTest {

    @Test("Remove File")
    func removeFile() async throws {
        
        let path = try makeFile(at: "file.txt")

        try FileSystem().removeItem(at: path)

        #expect(FileManager.default.fileExists(atPath: path.string) == false)

    }


    @Test("Remove Symlink")
    func removeSymlink() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let symlinkPath = try makeSymlink(at: "symlink.lnk", pointingTo: targetPath)

        let targetInfoBefore = try FileInfo(fileAt: targetPath)

        try FileSystem().removeItem(at: symlinkPath)

        #expect(FileManager.default.fileExists(atPath: symlinkPath.string) == false)
        
        let targetInfoAfter = try FileInfo(fileAt: targetPath)
        #expect(targetInfoBefore == targetInfoAfter)

    }


    @Test("Remove Empty Dir")
    func removeEmptyDir() async throws {
        
        let dirPath = try makeDir(at: "dir")
        
        try FileSystem().removeItem(at: dirPath)

        #expect(FileManager.default.fileExists(atPath: dirPath.string) == false)

    }


    @Test("Remove Non-Empty Dir")
    func removeNonEmptyDir() async throws {

        let structure = [
            "file1.txt": .file(contents: "Serika is Cute!"),
            "a": [
                "file2.txt": .file(contents: "Hoshino is Cute!"),
                "link1.lnk": .symlink(target: "../file1.txt"),
                "b": [
                    "file3.txt": .file(contents: "Swift is Great!")
                ],
                "link2.lnk": .symlink(target: "./b")
            ]
        ] as FileStructure

        let path = try makeFileStructure(at: "dir", structure: structure)

        try FileSystem().removeItem(at: path)

        #expect(FileManager.default.fileExists(atPath: path.string) == false)

    }


    @Test("Remove Not Exist Item")
    func removeNotExistItem() async throws {
        
        let path = makePath(at: "not-exist.txt")

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().removeItem(at: path)
        }

        #expect(error?.code == .fileNotFound)

    }

}
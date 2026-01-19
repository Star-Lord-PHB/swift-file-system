import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    final class ContentsOfDirTest: FileSystemTest {}

}



extension FileSystemTest.ContentsOfDirTest {

    @Test("Single Level Dir")
    func contentsOfSingleLevelDir() async throws {
        
        let structure = [
            "file1": .file(contents: "Serika is Cute"),
            "file2": .file(contents: "Kanna is Cute"),
            "link1": .symlink(target: "file1"),
            "link2": .symlink(target: "not-exist"),
        ] as FileStructure

        let path = try makeFileStructure(at: "dir", structure: structure)

        let expectedContents = [
            .init(path: "file1", type: .regular)!,
            .init(path: "file2", type: .regular)!,
            .init(path: "link1", type: .symlink)!,
            .init(path: "link2", type: .symlink)!,
        ] as Set<DirectoryEntry>

        let contents = Set(try FileSystem().contentsOfDirectory(at: path))

        #expect(contents == expectedContents)

    }


    @Test("Empty Dir")
    func contentsOfEmptyDir() async throws {

        let path = try makeDir(at: "empty-dir")

        let contents = try FileSystem().contentsOfDirectory(at: path)

        #expect(contents.isEmpty)

    }


    @Test("Multi Level Dir")
    func contentsOfMultiLevelDir() async throws {
        
        let structure = [
            "a": [
                "file1": .file(contents: "Serika is Cute"),
                "link1": .symlink(target: "file1"),
            ],
            "b": [
                "file2": .file(contents: "Hoshino is Cute"),
            ],
            "file3": .file(contents: "Hello Swift!"),
            "link2": .symlink(target: "a/link1"),
        ] as FileStructure

        let path = try makeFileStructure(at: "dir", structure: structure)

        let expectedContents = [
            .init(path: "a", type: .directory)!,
            .init(path: "b", type: .directory)!,
            .init(path: "file3", type: .regular)!,
            .init(path: "link2", type: .symlink)!,
        ] as Set<DirectoryEntry>

        let contents = Set(try FileSystem().contentsOfDirectory(at: path))

        #expect(contents == expectedContents)

    }

}
import Testing
import SystemPackage
import Foundation
@testable import FileSystem


extension FileSystemTest {

    final class DirectoryHandleTest: FileSystemTest {}

}



extension FileSystemTest.DirectoryHandleTest {

    @Test("Direct Entries")
    func directEntries() async throws {
        
        let dirPath = try makeDir(at: "dir")

        var entries = [
            try makeFile(at: "dir/file1.txt"),
            try makeFile(at: "dir/file2.txt"),
            try makeFile(at: "dir/file3.txt"),
            try makeSymlink(at: "dir/file4.txt", pointingTo: "./file1.txt"),
            try makeDir(at: "dir/subdir"),
            makePath(at: "dir/."),
            makePath(at: "dir/..")
        ] as Set<FilePath>

        _ = try makeFile(at: "dir/subdir/file4.txt")

        let dirHandle = try DirectoryHandle(forDirAt: dirPath)

        let info = try dirHandle.fileInfo()
        #expect(try FileInfo(fileAt: dirPath) == info)

        for entry in try dirHandle.directEntries() {
            // print(entry)
            #expect(entries.remove(entry.path) != nil)
        }

        #expect(entries.isEmpty)

    }


    @Test("Direct Entries Recursive")
    func directEntriesRecursive() async throws {

        let dirPath = try makeDir(at: "dir")

        var entries = [
            makePath(at: "dir/."),
            makePath(at: "dir/.."),
            try makeFile(at: "dir/file1.txt"),
            try makeFile(at: "dir/file2.txt"),
            try makeFile(at: "dir/file3.txt"),
            try makeSymlink(at: "dir/file4.txt", pointingTo: "./file1.txt"),
            try makeDir(at: "dir/subdir"),
            makePath(at: "dir/subdir/."),
            makePath(at: "dir/subdir/.."),
            try makeFile(at: "dir/subdir/file4.txt"),
            try makeFile(at: "dir/subdir/file5.txt"),
        ] as Set<FilePath>


        let dirHandle = try DirectoryHandle(forDirAt: dirPath)

        try dirHandle.entrySequence(recursive: true).forEach { result in
            let entry = try result.get()
            // print(entry)
            #expect(entries.remove(entry.path) != nil)
        }

        #expect(entries.isEmpty)

    }

}
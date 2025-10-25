import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class DirectoryTest: FileSystemTest {}

}



extension FileSystemTest.DirectoryTest {

    @Test("Direct Traversal")
    func directTraversal() async throws {
        
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

        try await expectNoResHandleLeak {

            let sequence = try DirectoryEntrySequence(dirAt: dirPath, recursive: false)

            try sequence.forEach { result in 
                let entry = try result.get()
                // print(entry)
                #expect(entries.remove(entry.path) != nil)
            }

            #expect(entries.isEmpty)

        }

    }



    @Test("Recursive Traversal")
    func recursiveTraversal() async throws {
        
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


        try await expectNoResHandleLeak {

            let sequence = try DirectoryEntrySequence(dirAt: dirPath, recursive: true)

            try sequence.forEach { result in
                let entry = try result.get()
                // print(entry)
                #expect(entries.remove(entry.path) != nil)
            }

            #expect(entries.isEmpty)

        }

    }

}
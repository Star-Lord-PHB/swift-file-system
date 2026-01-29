import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore


extension FileSystemTest {

    @Suite
    final class DirectoryHandleTest: FileSystemTest {}

}



extension FileSystemTest.DirectoryHandleTest {

    @Test("Direct Entries")
    func directEntries() async throws {
        
        let dirPath = try makeDir(at: "dir")

        print(dirPath)

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

            let dirHandle = try DirectoryHandle(forDirAt: dirPath)

            let info = try dirHandle.fileInfo()
            #expect(try FileInfo(fileAt: dirPath) == info)

            for entry in try dirHandle.directEntries(options: .includeDotEntries) {
                // print(entry)
                #expect(entries.remove(dirPath.appending(entry.path.components)) != nil)
            }

            #expect(entries.isEmpty)

            try dirHandle.close()

        } preheat: {
            preheatWindowsSecurityDescriptor(forFileAt: dirPath)
        }

    }


    @Test("Recursive Entries")
    func recursiveEntries() async throws {

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

            let dirHandle = try DirectoryHandle(forDirAt: dirPath)

            try dirHandle.entryRecursiveSequence(options: .includeDotEntries).forEach { result in
                let e = try result.get()
                switch e {
                    case .entry(let entry) where entry.type == .directory && entry.path.lastComponent?.kind == .regular: 
                        #expect(entries.contains(dirPath.appending(entry.path.components)))
                    case .entry(let entry):
                        #expect(entries.remove(dirPath.appending(entry.path.components)) != nil)
                    case .leavingDir(let path, .none):
                        #expect(entries.remove(dirPath.appending(path.components)) != nil)
                    case .leavingDir(_, .some(let err)):
                        throw err
                    case .entryError(_, let err): 
                        throw err
                    case .subTreeError(_, let err):
                        throw err
                }
                // print(e.path)
            }

            #expect(entries.isEmpty)

        }

    }

}
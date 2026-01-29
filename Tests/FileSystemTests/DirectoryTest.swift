import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    @Suite
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

            let sequence = try DirectoryEntryDirectSequence(dirAt: dirPath, options: .includeDotEntries)

            try sequence.forEach { result in 
                let entry = try result.get()
                // print(entry.path)
                #expect(entries.remove(dirPath.appending(entry.path.components)) != nil)
            }

            #expect(entries.isEmpty)

        }

    }


    @Test("Direct Traversal (skip dots and dir)")
    func directTraversalSkipDotsAndDir() async throws {
        
        let dirPath = try makeDir(at: "dir")

        var entries = [
            try makeFile(at: "dir/file1.txt"),
            try makeFile(at: "dir/file2.txt"),
            try makeFile(at: "dir/file3.txt"),
            try makeSymlink(at: "dir/file4.txt", pointingTo: "./file1.txt")
        ] as Set<FilePath>

        _ = try makeDir(at: "dir/subdir")
        _ = try makeFile(at: "dir/subdir/file4.txt")

        try await expectNoResHandleLeak {

            let sequence = try DirectoryEntryDirectSequence(dirAt: dirPath, options: [.skipDir])

            try sequence.forEach { result in 
                let entry = try result.get()
                // print(entry.path)
                #expect(entries.remove(dirPath.appending(entry.path.components)) != nil)
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

            let sequence = DirectoryEntryRecursiveSequence(dirAt: dirPath, options: .includeDotEntries)

            try sequence.forEach { result in
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


    @Test("Recursive Traversal (skip dots and dir)")
    func recursiveTraversalSkipDotsAndDir() async throws {
        
        let dirPath = try makeDir(at: "dir")

        _ = try makeDir(at: "dir/subdir")

        var entries = [
            try makeFile(at: "dir/file1.txt"),
            try makeFile(at: "dir/file2.txt"),
            try makeFile(at: "dir/file3.txt"),
            try makeSymlink(at: "dir/file4.txt", pointingTo: "./file1.txt"),
            try makeFile(at: "dir/subdir/file4.txt"),
            try makeFile(at: "dir/subdir/file5.txt"),
        ] as Set<FilePath>

        try await expectNoResHandleLeak {

            let sequence = DirectoryEntryRecursiveSequence(dirAt: dirPath, options: [.skipDir])

            try sequence.forEach { result in
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


    @Test("Symlink Direct Traversal")
    func symlinkDirectTraversal() async throws {
        
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

        let symlinkPath = try makeSymlink(at: "link", pointingTo: "dir") 

        try await expectNoResHandleLeak {

            let sequence = try DirectoryEntryDirectSequence(dirAt: symlinkPath, options: .includeDotEntries)

            try sequence.forEach { result in 
                let entry = try result.get()
                // print(entry.path)
                #expect(entries.remove(dirPath.appending(entry.path.components)) != nil)
            }

            #expect(entries.isEmpty)

        }

    }


    @Test("Symlink Recursive Traveral")
    func symlinkRecursiveTraversal() async throws {
        
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

        let symlinkPath = try makeSymlink(at: "link", pointingTo: "dir")

        try await expectNoResHandleLeak {

            let sequence = DirectoryEntryRecursiveSequence(dirAt: symlinkPath, options: .includeDotEntries)

            try sequence.forEach { result in
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
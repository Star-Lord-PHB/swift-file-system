import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    final class ItemExistsTest: FSIsolatedTestCase {}

}



extension FileSystemTest.ItemExistsTest {

    @Test("File Exists")
    func fileExists() async throws {
        
        let filePath = try makeFile(at: "file.txt")
        #expect(FileSystem().itemExists(at: filePath))

    }


    @Test("Directory Exists")
    func directoryExists() async throws {
        let dirPath = try makeDir(at: "directory")
        #expect(FileSystem().itemExists(at: dirPath))
    }


    @Test("Symlink Exists")
    func symlinkExists() async throws {
        
        let targetFilePath = try makeFile(at: "target.txt")
        let symlinkPath = try makeSymlink(at: "symlink.txt", pointingTo: targetFilePath)

        #expect(FileSystem().itemExists(at: symlinkPath))

    }


    @Test("Symlink with No Target Exists")
    func symlinkWithNoTargetExists() async throws {
        
        let targetPath = makePath(at: "target")
        let symlinkPath = try makeSymlink(at: "symlink.txt", pointingTo: targetPath)

        #expect(FileSystem().itemExists(at: symlinkPath))

    }


    @Test("Symlink Target Exists")
    func symlinkTargetExists() async throws {
        
        let targetFilePath = try makeFile(at: "target.txt")
        let symlinkPath = try makeSymlink(at: "symlink.txt", pointingTo: targetFilePath)

        #expect(FileSystem().itemExists(at: symlinkPath, followSymlinks: true))

    }


    @Test("Item Not Exists")
    func fileNotExists() async throws {
        
        let filePath = makePath(at: "file")
        #expect(FileSystem().itemExists(at: filePath) == false)

    }


    @Test("Symlink Target Not Exists")
    func symlinkTargetNotExists() async throws {
        
        let targetPath = makePath(at: "target.txt")
        let symlinkPath = try makeSymlink(at: "symlink.txt", pointingTo: targetPath)

        #expect(FileSystem().itemExists(at: symlinkPath, followSymlinks: true) == false)

    }

}
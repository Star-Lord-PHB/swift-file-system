import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class CreateSymlinkTest: FileSystemTest {}

}



extension FileSystemTest.CreateSymlinkTest {

    @Test("File Target")
    func createFileTargetSymlink() async throws {
        
        let targetPath = try makeFile(at: "target", contents: .init("Serika is Cute!".utf8))
        let symlinkPath = makePath(at: "link")

        let targetExpectation = try ItemExpectation.from(itemAt: targetPath)

        try FileSystem().createSymLink(at: symlinkPath, pointingTo: targetPath)

        #expect(try FileInfo(fileAt: symlinkPath, followSymLink: false).type == .symlink)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: symlinkPath.string) == targetPath.string)

        try expectItem(at: symlinkPath, toMatch: targetExpectation, followSymlink: true)

    }


    @Test("Directory Target")
    func createDirectoryTargetSymlink() async throws {

        let targetPath = try makeDir(at: "target")
        let symlinkPath = makePath(at: "link")

        let targetExpectation = try ItemExpectation.from(itemAt: targetPath)

        try FileSystem().createSymLink(at: symlinkPath, pointingTo: targetPath)

        #expect(try FileInfo(fileAt: symlinkPath, followSymLink: false).type == .symlink)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: symlinkPath.string) == targetPath.string)

        try expectItem(at: symlinkPath, toMatch: targetExpectation, followSymlink: true)

    }


    @Test("Symlink Target")
    func createSymlinkTargetSymlink() async throws {
        
        let finalTargetPath = try makeFile(at: "finalTarget", contents: .init("Serika is Cute!".utf8))
        let targetSymlinkPath = try makeSymlink(at: "targetLink", pointingTo: finalTargetPath)
        let symlinkPath = makePath(at: "link")

        let finalTargetExpectation = try ItemExpectation.from(itemAt: finalTargetPath)

        try FileSystem().createSymLink(at: symlinkPath, pointingTo: targetSymlinkPath)

        #expect(try FileInfo(fileAt: symlinkPath, followSymLink: false).type == .symlink)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: symlinkPath.string) == targetSymlinkPath.string)

        try expectItem(at: symlinkPath, toMatch: finalTargetExpectation, followSymlink: true)

    }

}
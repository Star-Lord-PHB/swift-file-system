import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class SymlinkDestinationTest: FileSystemTest {}

}



extension FileSystemTest.SymlinkDestinationTest {

    @Test("Direct Abs Dest")
    func symlinkDirectAbsDest() async throws {
        
        let targetPath = makePath(at: "target")
        let symlinkPath = try makeSymlink(at: "link", pointingTo: targetPath)

        let dest = try FileSystem().destinationOfSymLink(at: symlinkPath, recursive: false)

        #expect(dest == targetPath)

    }


    @Test("Direct Relative Dest")
    func symlinkDirectRelativeDest() async throws {
        
        let targetPath = "dir/target/../target" as FilePath
        let symlinkPath = try makeSymlink(at: "link", pointingTo: targetPath)

        let dest = try FileSystem().destinationOfSymLink(at: symlinkPath, recursive: false)

        #expect(dest == targetPath)

    }


    // TODO: Add tests for recursive destination resolution

}
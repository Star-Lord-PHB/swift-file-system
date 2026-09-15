#if !canImport(WinSDK)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// Entry kinds only POSIX has.
    @Suite("POSIX")
    struct RemovalPOSIXTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalPOSIXTests {


    @Test
    func `Removes a fifo inside a tree`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        try #require(mkfifo(root.appending("fifo").string, 0o644) == 0)

        try fileSystem.removeItem(at: root)

        try Support.expectItemNotExistNoFollow(at: root)

    }

}

#endif

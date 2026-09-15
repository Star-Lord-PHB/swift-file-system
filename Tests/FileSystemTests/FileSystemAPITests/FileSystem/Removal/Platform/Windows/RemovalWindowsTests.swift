#if canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// Entry kinds only Windows has.
    @Suite("Windows")
    struct RemovalWindowsTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalWindowsTests {


    @Test
    func `Removes a junction without touching its target`() throws {

        let target = try workspace.makeFixture(
            at: "target",
            [
                "file": .file(contents: "target contents"),
                "nested": [
                    "file": .file(contents: "nested contents")
                ],
            ]
        )
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        try Support.makeWindowsJunction(at: root.appending("junction"), pointingTo: target)
        let targetSnapshot = try Support.TreeSnapshot.capture(at: target)

        try fileSystem.removeItem(at: root)

        try Support.expectItemNotExistNoFollow(at: root)
        try Support.expectTree(at: target, matches: targetSnapshot, using: .unchanged)

    }

}

#endif

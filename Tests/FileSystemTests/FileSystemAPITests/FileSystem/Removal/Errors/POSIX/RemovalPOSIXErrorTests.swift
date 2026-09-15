#if !canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// A failure only POSIX can produce: an entry inside a directory that is readable but not
    /// searchable.
    @Suite("POSIX errors")
    struct RemovalPOSIXErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias RemovalTests = FileSystemAPITests.RemovalTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalPOSIXErrorTests {

    private func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }


    @Test
    func `File in a no-execute directory is reported and the rest is removed`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "ok.txt": .file(contents: "ok"),
                "r-only": [
                    "inner": .file(contents: "inner contents")
                ],
            ]
        )
        let rOnlyPath = root.appending("r-only")
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)
        try setPermissions(0o444, at: rOnlyPath)
        defer { try? setPermissions(0o755, at: rOnlyPath) }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        // The entry can be listed but neither examined nor unlinked without search permission.
        #expect(error?.kind == .permissionDenied)
        #expect(error?.operation == .remove(rOnlyPath.appending("inner")))
        try setPermissions(0o755, at: rOnlyPath)
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        expectation.removeItem(at: "ok.txt")
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "r-only": RemovalTests.restoredDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }

}

#endif

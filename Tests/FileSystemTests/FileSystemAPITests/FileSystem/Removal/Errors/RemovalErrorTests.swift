import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// The error contract of a recursive removal: everything that can be removed is removed, the
    /// first failure is thrown as its own `PlatformError` naming the entry, and the ancestors of a
    /// failed entry stay in place without errors of their own. The obstructions are installed by
    /// the platform-specific helpers in `RemovalObstructions.swift`; the scenarios and the
    /// assertions are the same everywhere.
    @Suite("Errors")
    struct RemovalErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias RemovalTests = FileSystemAPITests.RemovalTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalErrorTests {

    @Test
    func `Unremovable file in a subdirectory is reported and the rest is removed`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "locked": [
                    "inner": .file(contents: "inner contents")
                ],
                "z-dir": [
                    "file": .file(contents: "z contents")
                ],
            ]
        )
        let lockedPath = root.appending("locked")
        try RemovalTests.denyRemovalOfChildren(in: lockedPath)
        defer { RemovalTests.restoreRemovalOfChildren(in: lockedPath) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.operation == .remove(lockedPath.appending("inner")))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["a-file", "z-dir/file", "z-dir"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "locked": RemovalTests.enumeratedDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `Removal continues in a directory after its first unremovable entry`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "locked": [
                    "inner": .file(contents: "inner contents"),
                    "nested": [
                        "file": .file(contents: "nested contents")
                    ],
                ],
                "z-file": .file(contents: "z"),
            ]
        )
        let lockedPath = root.appending("locked")
        try RemovalTests.denyRemovalOfChildren(in: lockedPath)
        defer { RemovalTests.restoreRemovalOfChildren(in: lockedPath) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        // The enumeration order decides which of the two entries fails first.
        let operation = try #require(error?.operation)
        #expect([.remove(lockedPath.appending("inner")), .remove(lockedPath.appending("nested"))].contains(operation))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["z-file", "locked/nested/file"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "locked": RemovalTests.enumeratedDirectoryPolicy,
            "locked/nested": RemovalTests.survivingDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `Unremovable direct children keep the root and lose their own contents`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "dir": [
                    "file": .file(contents: "dir contents"),
                    "sub": [
                        "deep": .file(contents: "deep contents")
                    ],
                ],
            ]
        )
        try RemovalTests.denyRemovalOfChildren(in: root)
        defer { RemovalTests.restoreRemovalOfChildren(in: root) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        let operation = try #require(error?.operation)
        #expect([.remove(root.appending("a-file")), .remove(root.appending("dir"))].contains(operation))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["dir/file", "dir/sub/deep", "dir/sub"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.enumeratedDirectoryPolicy,
            "dir": RemovalTests.survivingDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `Unremovable root fails before touching its contents`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let parent = try workspace.makeDirectory(at: "parent")
        let root = try workspace.makeFixture(
            at: "parent/directory",
            [
                "file": .file(contents: "contents"),
                "sub": [
                    "nested": .file(contents: "nested contents")
                ],
            ]
        )
        try RemovalTests.denyRemovalOfChildren(in: parent)
        defer { RemovalTests.restoreRemovalOfChildren(in: parent) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.operation == .remove(root))
        try Support.expectTree(at: root, matches: rootSnapshot, using: .unchanged)

    }


    @Test
    func `Unlistable empty directory is removed with the rest`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "sealed": [:],
            ]
        )
        let sealedPath = root.appending("sealed")
        try RemovalTests.denyListing(of: sealedPath)
        defer { RemovalTests.restoreListing(of: sealedPath) }

        try fileSystem.removeItem(at: root)

        try Support.expectItemNotExistNoFollow(at: root)

    }


    @Test
    func `Unlistable directory with contents is reported and the rest is removed`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "sealed": [
                    "inner": .file(contents: "inner contents")
                ],
                "z-dir": [
                    "file": .file(contents: "z contents")
                ],
            ]
        )
        let sealedPath = root.appending("sealed")
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)
        try RemovalTests.denyListing(of: sealedPath)
        defer { RemovalTests.restoreListing(of: sealedPath) }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.operation == .remove(sealedPath))
        RemovalTests.restoreListing(of: sealedPath)
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["a-file", "z-dir/file", "z-dir"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "sealed": RemovalTests.restoredDirectoryPolicy,
            "sealed/inner": RemovalTests.childOfRestoredDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `Unlistable root is reported and nothing is removed`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "sub": [
                    "nested": .file(contents: "nested contents")
                ],
            ]
        )
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)
        try RemovalTests.denyListing(of: root)
        defer { RemovalTests.restoreListing(of: root) }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.operation == .remove(root))
        RemovalTests.restoreListing(of: root)
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        try expectation.updatePolicies([
            "": RemovalTests.restoredDirectoryPolicy,
            "file": RemovalTests.childOfRestoredDirectoryPolicy,
            "sub": RemovalTests.childOfRestoredDirectoryPolicy,
            "sub/nested": RemovalTests.childOfRestoredDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }

}

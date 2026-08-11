#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("POSIX traversal errors")
    struct POSIXTraversalErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.POSIXTraversalErrorTests {

    private func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }


    /// Restores permissions that would otherwise keep the workspace from being cleaned up.
    private func restoreDefaultDirectoryPermissions(at path: FilePath) {
        try? setPermissions(0o755, at: path)
    }


    @Test
    func `Unreadable subdirectory reports errors and the rest is copied`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }
        #if !canImport(Darwin) && !canImport(Glibc) && !canImport(Musl)
        try Test.cancel("Unverified platform behavior")
        #endif

        let src = try workspace.makeFixture(
            at: "src",
            [
                "a-file": .file(contents: "a"),
                "locked": [
                    "inner": .file(contents: "inner contents")
                ],
                "z-file": .file(contents: "z"),
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let lockedPath = src.appending("locked")
        try setPermissions(0o000, at: lockedPath)
        defer { restoreDefaultDirectoryPermissions(at: lockedPath) }

        let report = fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        // The directory is created and committed with its (restricted) source metadata, only
        // its children are missing. Restore its mode so the assertions can enumerate it; the
        // policy below excludes permissions accordingly.
        restoreDefaultDirectoryPermissions(at: dst.appending("locked"))

        #if canImport(Darwin)
        // The enumerator cannot open the directory, and the metadata commit cannot open the
        // unreadable source for its extended attributes and ACL.
        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [
                ("locked", .copyContents, .permissionDenied),
                ("locked", .copyExtendedAttributes, .permissionDenied),
                ("locked", .copyDarwinACL, .permissionDenied),
            ]
        )
        #else
        // Reading the directory's inode flags fails while caching, and the enumerator
        // cannot open it.
        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [
                ("locked", .copyFlags, .permissionDenied),
                ("locked", .copyContents, .permissionDenied),
            ]
        )
        #endif
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        expectation.removeItem(at: "locked/inner")
        try expectation.updatePolicies(["locked": .copiedItem.excluding(.permissions)])
        try Support.expectTree(at: dst, matches: expectation)

    }


    @Test
    func `No-execute directory reports each child and copies the rest`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let src = try workspace.makeFixture(
            at: "src",
            [
                "ok.txt": .file(contents: "ok"),
                "r-only": [
                    "inner": .file(contents: "inner contents")
                ],
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let rOnlyPath = src.appending("r-only")
        try setPermissions(0o444, at: rOnlyPath)
        defer { restoreDefaultDirectoryPermissions(at: rOnlyPath) }

        let report = fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        // Restore the copied directory's mode (it received the restricted source mode, which
        // is excluded from comparison below) so the exact-tree sweep can enumerate it.
        restoreDefaultDirectoryPermissions(at: dst.appending("r-only"))

        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            // The child's type still comes from the directory entry, so the failure surfaces
            // when its contents cannot be opened.
            errors: [("r-only/inner", .copyContents, .permissionDenied)]
        )
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        expectation.removeItem(at: "r-only/inner")
        // The directory is copied with its current restricted mode, which the earlier
        // snapshot cannot match.
        try expectation.updatePolicies(["r-only": .copiedItem.excluding(.permissions)])
        try Support.expectTree(at: dst, matches: expectation)

    }

}

#endif

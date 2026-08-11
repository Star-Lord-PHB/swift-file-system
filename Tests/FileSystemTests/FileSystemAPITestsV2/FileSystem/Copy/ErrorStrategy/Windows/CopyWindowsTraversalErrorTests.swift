#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Windows traversal errors")
    struct WindowsTraversalErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.WindowsTraversalErrorTests {

    private func denyListing(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let entries = [
            WindowsExplicitAccess(
                permission: .listDirectory,
                accessMode: .denyAccess,
                trustee: .everyone
            ),
            WindowsExplicitAccess(permission: .genericAll, trustee: .everyone)
        ]
        try Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: .init(entries)),
            at: path,
            followSymlink: true,
            sourceLocation: sourceLocation
        )
    }


    private func restoreFullAccess(at path: FilePath) {
        let entries = [
            WindowsExplicitAccess(permission: .genericAll, trustee: .everyone)
        ]
        try? Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: .init(entries)),
            at: path,
            followSymlink: true
        )
    }


    /// Cancels the test when the current token can still list the directory despite the deny ACE
    /// (for example a token with enabled backup privileges).
    private func requireListingDenied(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var findData = WIN32_FIND_DATAW()
        let handle = path.appending("*").withPlatformString { pattern in
            FindFirstFileW(pattern, &findData)
        }
        if let handle, handle != INVALID_HANDLE_VALUE {
            FindClose(handle)
            try Test.cancel(
                "The current token is not subject to the installed deny ACE",
                sourceLocation: sourceLocation
            )
        }
    }


    @Test
    func `List-denied subdirectory reports one error and the rest is copied`() throws {

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
        try denyListing(at: lockedPath)
        defer { restoreFullAccess(at: lockedPath) }
        try requireListingDenied(at: lockedPath)

        let report = try fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        // Restore listing on the copied directory (its DACL was copied from the deny-listing
        // source state) so the exact-tree sweep below can enumerate it.
        restoreFullAccess(at: dst.appending("locked"))

        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [("locked", .copyContents, .permissionDenied)]
        )
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        expectation.removeItem(at: "locked/inner")
        // The directory itself is created and committed; its DACL came from the current
        // (deny-listing) source state, which the pre-deny snapshot cannot match.
        try expectation.updatePolicies(["locked": .copiedItem.excluding(.permissions)])
        try Support.expectTree(at: dst, matches: expectation)

    }

}

#endif

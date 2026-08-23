#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests.ErrorHandlingTests {

    @Suite("Windows traversal errors")
    struct WindowsTraversalErrorTests {

        typealias Support = DirectorySequenceAPITests.Support
        typealias TraversalLog = DirectorySequenceAPITests.ErrorHandlingTests.TraversalLog

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.ErrorHandlingTests.WindowsTraversalErrorTests {

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
    func `List-denied subdirectory reports a sub-tree error and siblings are still visited`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "locked": [
                    "inner": .file(contents: "inner contents")
                ],
                "z-file": .file(contents: "z")
            ]
        )
        let lockedPath = path.appending("locked")
        try denyListing(at: lockedPath)
        defer { restoreFullAccess(at: lockedPath) }
        try requireListingDenied(at: lockedPath)

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }
        let log = TraversalLog(elements: elements)

        #expect(log.entries.map(\.path).contains("a-file"))
        #expect(log.entries.map(\.path).contains("z-file"))
        #expect(log.entries.map(\.path).contains("locked"))
        #expect(!log.entries.map(\.path).contains("locked/inner"))
        try #require(log.subTreeErrors.count == 1)
        #expect(log.subTreeErrors[0].path == "locked")
        #expect(log.subTreeErrors[0].error.kind == .permissionDenied)
        #expect(log.cleanLeavingDirectories.isEmpty)
        #expect(log.leavingDirectoryErrors.isEmpty)
        #expect(log.entryErrors.isEmpty)

    }


    @Test
    func `Direct sequence fails to open a list-denied root`() throws {

        let path = try workspace.makeDirectory(at: "locked-root")
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try requireListingDenied(at: path)

        let error = #expect(throws: PlatformError.self) {
            _ = try DirectoryEntryDirectSequence(dirAt: path)
        }

        #expect(error?.kind == .permissionDenied)

    }


    @Test
    func `Recursive sequence reports a list-denied root and ends`() throws {

        let path = try workspace.makeDirectory(at: "locked-root")
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try requireListingDenied(at: path)

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        let error = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #expect(error?.kind == .permissionDenied)
        #expect(iterator.next() == nil)

    }

}

#endif

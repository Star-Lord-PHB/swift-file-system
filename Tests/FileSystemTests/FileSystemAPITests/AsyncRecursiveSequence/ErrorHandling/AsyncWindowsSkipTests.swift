#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests.ErrorHandlingTests {

    @Suite("Windows skip over sub-tree errors")
    struct WindowsSkipTests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support
        typealias ElementShape = AsyncRecursiveSequenceAPITests.ElementShape
        typealias SkipTrigger = AsyncRecursiveSequenceAPITests.SkipTrigger

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: `SwiftFileSystem` is imported for the synchronous oracle only; see `AsyncSkipSupport.swift`.
extension AsyncRecursiveSequenceAPITests.ErrorHandlingTests.WindowsSkipTests {

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


    @Test(arguments: [1, 2, 3, 4, 128])
    func `Skipping descendants of a list-denied directory yields the same elements as the synchronous iterator`(
        batchCount: Int
    ) async throws {

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

        let trigger = SkipTrigger(after: .entry("locked", .directory), .skipDescendants)
        let expected = try AsyncRecursiveSequenceAPITests.runSync(
            DirectoryEntryRecursiveSequence(dirAt: path),
            triggers: [trigger]
        )

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path, batchCount: batchCount)
        let elements = try await AsyncRecursiveSequenceAPITests.run(sequence, triggers: [trigger])

        #expect(elements == expected)
        #expect(!elements.contains(.subTreeError("locked", .permissionDenied)))

    }


    // With the larger batches the sub-tree error of the list-denied directory is already buffered inside the
    // skipped region, where it is the closing element of that directory rather than one more entry.
    @Test(arguments: [1, 2, 3, 4, 128])
    func `Skipping descendants of a directory holding a list-denied one yields the same elements as the synchronous iterator`(
        batchCount: Int
    ) async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "dir1": [
                    "f1": .file(contents: "f1"),
                    "locked": [
                        "inner": .file(contents: "inner contents")
                    ],
                    "g1": .file(contents: "g1"),
                    "sub": [
                        "deep": .file(contents: "deep")
                    ]
                ],
                "z-file": .file(contents: "z")
            ]
        )
        let lockedPath = path.appending("dir1/locked")
        try denyListing(at: lockedPath)
        defer { restoreFullAccess(at: lockedPath) }
        try requireListingDenied(at: lockedPath)

        let trigger = SkipTrigger(after: .entry("dir1", .directory), .skipDescendants)
        let expected = try AsyncRecursiveSequenceAPITests.runSync(
            DirectoryEntryRecursiveSequence(dirAt: path),
            triggers: [trigger]
        )

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path, batchCount: batchCount)
        let elements = try await AsyncRecursiveSequenceAPITests.run(sequence, triggers: [trigger])

        #expect(elements == expected)
        #expect(!elements.contains { $0.path.starts(with: "dir1") && $0.path != "dir1" })

    }

}

#endif

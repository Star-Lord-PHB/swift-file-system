#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests.ErrorHandlingTests {

    @Suite("POSIX skip over sub-tree errors")
    struct POSIXSkipTests {

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
extension AsyncRecursiveSequenceAPITests.ErrorHandlingTests.POSIXSkipTests {

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


    @Test(arguments: [1, 2, 3, 4, 128])
    func `Skipping descendants of an unreadable directory yields the same elements as the synchronous iterator`(
        batchCount: Int
    ) async throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

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
        try setPermissions(0o000, at: lockedPath)
        defer { restoreDefaultDirectoryPermissions(at: lockedPath) }

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


    // With the larger batches the sub-tree error of the unreadable directory is already buffered inside the
    // skipped region, where it is the closing element of that directory rather than one more entry.
    @Test(arguments: [1, 2, 3, 4, 128])
    func `Skipping descendants of a directory holding an unreadable one yields the same elements as the synchronous iterator`(
        batchCount: Int
    ) async throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

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
        try setPermissions(0o000, at: lockedPath)
        defer { restoreDefaultDirectoryPermissions(at: lockedPath) }

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

#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension RecursiveSequenceAPITests.ErrorHandlingTests {

    @Suite("POSIX traversal errors")
    struct POSIXTraversalErrorTests {

        typealias Support = RecursiveSequenceAPITests.Support
        typealias TraversalLog = RecursiveSequenceAPITests.ErrorHandlingTests.TraversalLog

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension RecursiveSequenceAPITests.ErrorHandlingTests.POSIXTraversalErrorTests {

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

}



extension RecursiveSequenceAPITests.ErrorHandlingTests.POSIXTraversalErrorTests {

    @Test
    func `Unreadable subdirectory reports a sub-tree error and siblings are still visited`() throws {

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
    func `Entries of a readable no-search directory are listed with their directory-entry kinds`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "read-only": [
                    "inner": .file(contents: "inner contents")
                ]
            ]
        )
        let readOnlyPath = path.appending("read-only")
        try setPermissions(0o444, at: readOnlyPath)
        defer { restoreDefaultDirectoryPermissions(at: readOnlyPath) }

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }
        let log = TraversalLog(elements: elements)

        #expect(log.entries.map(\.path) == ["read-only", "read-only/inner"])
        #expect(log.entries.map(\.type) == [.directory, .regular])
        #expect(log.entryErrors.isEmpty)
        #expect(log.cleanLeavingDirectories == ["read-only"])
        #expect(log.leavingDirectoryErrors.isEmpty)
        #expect(log.subTreeErrors.isEmpty)

    }


    @Test
    func `Recursive sequence reports an unreadable root and ends`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let path = try workspace.makeDirectory(at: "locked-root")
        try setPermissions(0o000, at: path)
        defer { restoreDefaultDirectoryPermissions(at: path) }

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        let error = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #expect(error?.kind == .permissionDenied)
        #expect(iterator.next() == nil)

    }



    // Skipping the directory keeps the iterator from trying to open it, so the failure it would have reported
    // never happens: the outcome is the traversal with the directory's region, here its sub-tree error, removed.
    @Test
    func `Skipping descendants of an unreadable directory reports no sub-tree error`() throws {

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

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try RecursiveSequenceAPITests.run(sequence)
        let expected = try baseline.removingRegion(of: "locked")

        let elements = try RecursiveSequenceAPITests.run(
            sequence,
            triggers: [.init(after: .entry("locked", .directory), .skipDescendants)]
        )

        #expect(baseline.contains(.subTreeError("locked", .permissionDenied)))
        #expect(elements == expected)

    }

}

#endif

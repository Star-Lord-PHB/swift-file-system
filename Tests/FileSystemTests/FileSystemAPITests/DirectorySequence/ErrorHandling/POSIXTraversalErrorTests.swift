#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests.ErrorHandlingTests {

    @Suite("POSIX traversal errors")
    struct POSIXTraversalErrorTests {

        typealias Support = DirectorySequenceAPITests.Support
        typealias TraversalLog = DirectorySequenceAPITests.ErrorHandlingTests.TraversalLog

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.ErrorHandlingTests.POSIXTraversalErrorTests {

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



extension DirectorySequenceAPITests.ErrorHandlingTests.POSIXTraversalErrorTests {

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
    func `Entries of a readable no-search directory report entry errors`() throws {

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

        #expect(log.entries.map(\.path) == ["read-only"])
        try #require(log.entryErrors.count == 1)
        #expect(log.entryErrors[0].path == "read-only/inner")
        #expect(log.entryErrors[0].error.kind == .permissionDenied)
        #expect(log.cleanLeavingDirectories == ["read-only"])
        #expect(log.leavingDirectoryErrors.isEmpty)
        #expect(log.subTreeErrors.isEmpty)

    }


    @Test
    func `Direct sequence fails to open an unreadable root`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let path = try workspace.makeDirectory(at: "locked-root")
        try setPermissions(0o000, at: path)
        defer { restoreDefaultDirectoryPermissions(at: path) }

        let error = #expect(throws: PlatformError.self) {
            _ = try DirectoryEntryDirectSequence(dirAt: path)
        }

        #expect(error?.kind == .permissionDenied)

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

}

#endif

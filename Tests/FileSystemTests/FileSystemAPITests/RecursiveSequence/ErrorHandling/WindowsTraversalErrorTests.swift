#if canImport(WinSDK)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension RecursiveSequenceAPITests.ErrorHandlingTests {

    @Suite("Windows traversal errors")
    struct WindowsTraversalErrorTests {

        typealias Support = RecursiveSequenceAPITests.Support
        typealias TraversalLog = RecursiveSequenceAPITests.ErrorHandlingTests.TraversalLog

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension RecursiveSequenceAPITests.ErrorHandlingTests.WindowsTraversalErrorTests {

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
        try Support.requireListingDenied(at: lockedPath)

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map(\.self)
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
    func `Recursive sequence reports a list-denied root and ends`() throws {

        let path = try workspace.makeDirectory(at: "locked-root")
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try Support.requireListingDenied(at: path)

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let error = #expect(throws: PlatformError.self) {
            _ = try iterator.next()
        }
        #expect(error?.kind == .permissionDenied)
        #expect(try iterator.next() == nil)

    }



    // Skipping the directory keeps the iterator from trying to open it, so the failure it would have reported
    // never happens: the outcome is the traversal with the directory's region, here its sub-tree error, removed.
    @Test
    func `Skipping descendants of a list-denied directory reports no sub-tree error`() throws {

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
        try Support.requireListingDenied(at: lockedPath)

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

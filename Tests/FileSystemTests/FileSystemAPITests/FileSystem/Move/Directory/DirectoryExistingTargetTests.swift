import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Directory onto existing target")
    struct DirectoryExistingTargetTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.DirectoryExistingTargetTests {

    enum TargetKind: String, CaseIterable {
        case file
        case symlinkToDirectory
        case danglingSymlink
        case emptyDirectory
        case nonEmptyDirectory
    }


    /// Creates the source tree at `src-tree` and returns its root.
    private func makeSourceTree() throws -> FilePath {
        try workspace.makeFixture(
            at: "src-tree",
            [
                "file": .file(contents: "source file contents"),
                "nested": [
                    "link": .symlink(target: "../file")
                ]
            ]
        )
    }


    /// Creates the destination item at `container/dst`, plus whatever the kind needs around it.
    private func makeExistingTarget(_ kind: TargetKind) throws -> FilePath {
        switch kind {
            case .file:
                return try workspace.makeFile(at: "container/dst", contents: "existing contents")
            case .symlinkToDirectory:
                let dstTarget = try workspace.makeDirectory(at: "link-target")
                return try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
            case .danglingSymlink:
                return try workspace.makeSymlink(at: "container/dst", pointingTo: workspace.path("missing"))
            case .emptyDirectory:
                return try workspace.makeDirectory(at: "container/dst")
            case .nonEmptyDirectory:
                try workspace.makeFile(at: "container/dst/other", contents: "other contents")
                return workspace.path("container/dst")
        }
    }


    @Test
    func `Overwrite replaces an empty directory`() throws {

        let src = try makeSourceTree()
        let dst = try workspace.makeDirectory(at: "container/dst")
        let treeSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)

        // The rename touches only the root's directory entry, which replaced an existing
        // one; children are fully unchanged, down to their status-change times.
        var expectation = Support.TreeExpectation(matching: treeSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": FileSystemAPITests.MoveTests.replacedItemPolicy])
        try Support.expectTree(at: dst, matches: expectation)
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Overwrite onto a non-empty directory fails and does not merge`() throws {

        let src = try makeSourceTree()
        let dst = try makeExistingTarget(.nonEmptyDirectory)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)
        }

        #expect(error?.kind == .notEmptyDirectory)
        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: [TargetKind.file, .symlinkToDirectory, .danglingSymlink])
    func `Overwrite onto a non-directory fails`(kind: TargetKind) throws {

        let src = try makeSourceTree()
        let dst = try makeExistingTarget(kind)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)
        }

        #expect(error?.kind == .notADirectory)
        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: TargetKind.allCases)
    func `Skip preserves source tree and existing target`(kind: TargetKind) throws {

        let src = try makeSourceTree()
        let dst = try makeExistingTarget(kind)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .skip)

        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: TargetKind.allCases)
    func `Existing-target error fails and changes nothing`(kind: TargetKind) throws {

        let src = try makeSourceTree()
        let dst = try makeExistingTarget(kind)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }

}

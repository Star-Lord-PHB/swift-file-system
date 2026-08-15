import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Directory")
    struct DirectoryMoveTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.DirectoryMoveTests {

    /// A tree with nested directories, files, an in-tree relative symlink, and a dangling one.
    static var sampleTree: FileSystemTestSupport.Fixture {
        [
            "file1": .file(contents: "file one contents"),
            "nested": [
                "file2": .file(contents: "file two contents"),
                "relative-link": .symlink(target: "file2"),
                "deeper": [
                    "file3": .file(contents: "file three contents")
                ]
            ],
            "dangling-link": .symlink(target: "missing")
        ]
    }


    @Test
    func `Move relocates the entire tree`() throws {

        let src = try workspace.makeFixture(at: "src-tree", Self.sampleTree)
        let dst = workspace.path("dst-tree")
        let treeSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst)

        // The rename touches only the root's directory entry: children are fully
        // unchanged, down to their status-change times.
        var expectation = Support.TreeExpectation(matching: treeSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": .movedItem])
        try Support.expectTree(at: dst, matches: expectation)
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Move into an existing parent directory`() throws {

        let src = try workspace.makeFixture(at: "src-tree", Self.sampleTree)
        try workspace.makeDirectory(at: "container")
        let dst = workspace.path("container/dst-tree")
        let treeSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst)

        var expectation = Support.TreeExpectation(matching: treeSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": .movedItem])
        try Support.expectTree(at: dst, matches: expectation)
        try Support.expectItemNotExistNoFollow(at: src)

    }

}

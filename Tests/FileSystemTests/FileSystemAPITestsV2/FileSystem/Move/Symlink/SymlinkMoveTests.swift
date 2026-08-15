import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Symlink")
    struct SymlinkMoveTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.SymlinkMoveTests {

    @Test
    func `Move relocates the link itself and preserves its target file`() throws {

        let srcTarget = try workspace.makeFile(at: "src-target", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let srcTargetSnapshot = try Support.ItemSnapshot.capture(at: srcTarget)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("moved-link")

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)
        try Support.expectItem(at: srcTarget, matches: srcTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Moved relative symlink keeps its target text verbatim`() throws {

        try workspace.makeFile(at: "neighbor.txt", contents: "neighbor contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: "neighbor.txt")
        try workspace.makeDirectory(at: "container")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("container/moved-link")

        try fileSystem.moveItem(at: src, to: dst)

        // The payload comparison pins the raw target text, not what it resolves to.
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        // From its new directory the same text no longer resolves to anything.
        #expect(!FileManager.default.fileExists(atPath: dst.string))

    }


    @Test
    func `Dangling symlink moves`() throws {

        let src = try workspace.makeSymlink(at: "src-link", pointingTo: workspace.path("missing"))
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("moved-link")

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Directory symlink moves as a link`() throws {

        try workspace.makeFile(at: "src-target/child", contents: "child contents")
        let srcTarget = workspace.path("src-target")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let srcTargetSnapshot = try Support.TreeSnapshot.capture(at: srcTarget)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("moved-link")

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)
        try Support.expectTree(at: srcTarget, matches: srcTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Overwrite replaces an existing file with the link`() throws {

        let srcTarget = try workspace.makeFile(at: "src-target", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = try workspace.makeFile(at: "dst", contents: "existing contents")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)

        try Support.expectItem(
            at: dst,
            matches: srcSnapshot,
            using: FileSystemAPITests.MoveTests.replacedItemPolicy
        )
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Overwrite onto a directory fails and preserves both sides`() throws {

        let srcTarget = try workspace.makeFile(at: "src-target", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        try workspace.makeFile(at: "container/dst/child", contents: "child contents")
        let dst = workspace.path("container/dst")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)
        }

        #expect(error?.kind.maybe(.isADirectory) == true)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: [false, true])
    func `Skip preserves source link and existing target`(dstIsDirectory: Bool) throws {

        let srcTarget = try workspace.makeFile(at: "src-target", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst: FilePath = if dstIsDirectory {
            try workspace.makeDirectory(at: "container/dst")
        } else {
            try workspace.makeFile(at: "container/dst", contents: "existing contents")
        }
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .skip)

        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: [false, true])
    func `Existing-target error fails and changes nothing`(dstIsDirectory: Bool) throws {

        let srcTarget = try workspace.makeFile(at: "src-target", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst: FilePath = if dstIsDirectory {
            try workspace.makeDirectory(at: "container/dst")
        } else {
            try workspace.makeFile(at: "container/dst", contents: "existing contents")
        }
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }

}

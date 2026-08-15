import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Regular file onto existing target")
    struct RegularFileExistingTargetTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.RegularFileExistingTargetTests {

    enum TargetKind: String, CaseIterable {
        case file
        case symlinkToFile
        case symlinkToDirectory
        case danglingSymlink
        case directory
    }


    /// Creates the destination item at `container/dst`, plus whatever the kind needs around it.
    private func makeExistingTarget(_ kind: TargetKind) throws -> FilePath {
        switch kind {
            case .file:
                return try workspace.makeFile(at: "container/dst", contents: "existing contents")
            case .symlinkToFile:
                let dstTarget = try workspace.makeFile(at: "link-target", contents: "target contents")
                return try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
            case .symlinkToDirectory:
                let dstTarget = try workspace.makeDirectory(at: "link-target")
                return try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
            case .danglingSymlink:
                return try workspace.makeSymlink(at: "container/dst", pointingTo: workspace.path("missing"))
            case .directory:
                try workspace.makeFile(at: "container/dst/child", contents: "child contents")
                return workspace.path("container/dst")
        }
    }


    @Test
    func `Overwrite replaces an existing file`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
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


    @Test(arguments: [.symlinkToFile, .symlinkToDirectory, .danglingSymlink] as [TargetKind])
    func `Overwrite replaces the symlink itself and preserves its target`(kind: TargetKind) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try makeExistingTarget(kind)
        var dstTargetSnapshot: Support.ItemSnapshot? = nil
        if kind != .danglingSymlink {
            dstTargetSnapshot = try Support.ItemSnapshot.capture(at: workspace.path("link-target"))
        }
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)

        // The link itself is replaced by the moved regular file; nothing is resolved.
        try Support.expectItem(
            at: dst,
            matches: srcSnapshot,
            using: FileSystemAPITests.MoveTests.replacedItemPolicy
        )
        try Support.expectItemNotExistNoFollow(at: src)
        if let dstTargetSnapshot {
            try Support.expectItem(
                at: workspace.path("link-target"),
                matches: dstTargetSnapshot,
                using: .unchanged
            )
        } else {
            try Support.expectItemNotExistNoFollow(at: workspace.path("missing"))
        }

    }


    @Test
    func `Overwrite onto a directory fails and preserves both sides`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
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


    @Test(arguments: TargetKind.allCases)
    func `Skip preserves source and existing target`(kind: TargetKind) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try makeExistingTarget(kind)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .skip)

        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: TargetKind.allCases)
    func `Existing-target error fails and changes nothing`(kind: TargetKind) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try makeExistingTarget(kind)
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

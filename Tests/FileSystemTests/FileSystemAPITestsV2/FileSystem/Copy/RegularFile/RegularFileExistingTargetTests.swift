import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

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



extension FileSystemAPITests.CopyTests.RegularFileExistingTargetTests {

    enum TargetKind: String, CaseIterable {
        case file
        case symlink
        case danglingSymlink
        case directory
    }


    /// Creates the destination item at `container/dst`, plus whatever the kind needs around it.
    private func makeExistingTarget(_ kind: TargetKind) throws -> FilePath {
        switch kind {
            case .file:
                return try workspace.makeFile(at: "container/dst", contents: "existing contents")
            case .symlink:
                let dstTarget = try workspace.makeFile(at: "link-target", contents: "target contents")
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
        let dst = try workspace.makeFile(at: "container/dst", contents: "existing contents")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        // The temporary file used for the replacement must not survive.
        let containerEntries = try FileManager.default.contentsOfDirectory(
            atPath: workspace.path("container").string
        )
        #expect(containerEntries == ["dst"])

    }


    @Test
    func `Overwrite replaces an existing symlink and preserves target`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dstTarget = try workspace.makeFile(at: "link-target", contents: "target contents")
        let dst = try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dstTargetSnapshot = try Support.ItemSnapshot.capture(at: dstTarget)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        try Support.expectItem(at: dstTarget, matches: dstTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Overwrite replaces a dangling symlink without creating its target`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let missing = workspace.path("missing")
        let dst = try workspace.makeSymlink(at: "container/dst", pointingTo: missing)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        try Support.expectItemNotExistNoFollow(at: missing)

    }


    @Test
    func `Overwrite onto a directory fails`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        try workspace.makeFile(at: "container/dst/child", contents: "child contents")
        let dst = workspace.path("container/dst")
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .overwrite),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .isADirectory)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)

    }


    @Test(arguments: TargetKind.allCases)
    func `Skip leaves an existing target unchanged`(kind: TargetKind) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try makeExistingTarget(kind)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))
        var dstTargetSnapshot: Support.ItemSnapshot? = nil
        if kind == .symlink {
            dstTargetSnapshot = try Support.ItemSnapshot.capture(at: workspace.path("link-target"))
        }

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .skip))

        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)
        if let dstTargetSnapshot {
            try Support.expectItem(
                at: workspace.path("link-target"),
                matches: dstTargetSnapshot,
                using: .unchanged
            )
        }

    }


    @Test(arguments: TargetKind.allCases)
    func `Existing-target error fails and changes nothing`(kind: TargetKind) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try makeExistingTarget(kind)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))
        var dstTargetSnapshot: Support.ItemSnapshot? = nil
        if kind == .symlink {
            dstTargetSnapshot = try Support.ItemSnapshot.capture(at: workspace.path("link-target"))
        }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .error),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectTree(at: workspace.path("container"), matches: containerSnapshot, using: .unchanged)
        if let dstTargetSnapshot {
            try Support.expectItem(
                at: workspace.path("link-target"),
                matches: dstTargetSnapshot,
                using: .unchanged
            )
        }

    }

}

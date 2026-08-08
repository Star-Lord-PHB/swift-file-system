import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Symlink as target")
    struct SymlinkCopyTargetTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.SymlinkCopyTargetTests {

    @Test
    func `Copies the target file when the root is a link`() throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = workspace.path("dst")
        let srcTargetSnapshot = try Support.ItemSnapshot.capture(at: srcTarget)
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(symlinkOption: .copyTarget))

        try Support.expectItem(at: dst, matches: srcTargetSnapshot, using: .copiedItem)
        try Support.expectItem(at: src, matches: linkSnapshot, using: .unchanged.excluding(.accessTime))
        try Support.expectItem(
            at: srcTarget,
            matches: srcTargetSnapshot,
            using: .unchanged.excluding(.accessTime)
        )

    }


    @Test
    func `Copies the target tree and keeps nested links as links`() throws {

        let srcTargetDir = try workspace.makeFixture(
            at: "target-dir",
            [
                "file.txt": .file(contents: "contents"),
                "inner-link": .symlink(target: "file.txt"),
                "nested": [
                    "deep.txt": .file(contents: "deep contents")
                ],
            ]
        )
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTargetDir)
        let dst = workspace.path("dst-dir")
        let srcTargetSnapshot = try Support.TreeSnapshot.capture(at: srcTargetDir)

        try fileSystem.copyItem(at: src, to: dst, options: .init(symlinkOption: .copyTarget))

        // Only the root link is resolved; "inner-link" must arrive as a symlink, which the
        // tree comparison asserts through its payload.
        try Support.expectTree(at: dst, matches: srcTargetSnapshot, using: .copiedItem)

    }


    @Test
    func `Copying a dangling root link fails`() throws {

        let src = try workspace.makeSymlink(at: "src-link", pointingTo: workspace.path("missing"))
        let dst = workspace.path("dst")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(symlinkOption: .copyTarget),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .notFound)
        try Support.expectItemNotExistNoFollow(at: dst)

    }


    @Test
    func `Copying a self-referencing link fails`() throws {

        let src = try workspace.makeSymlink(at: "src-link", pointingTo: workspace.path("src-link"))
        let dst = workspace.path("dst")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(symlinkOption: .copyTarget),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .pathResolutionFailed)
        try Support.expectItemNotExistNoFollow(at: dst)

    }


    @Test
    func `Copies a non-link root normally`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "copied contents")
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(symlinkOption: .copyTarget))

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Overwrite replaces an existing file with the target contents`() throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = try workspace.makeFile(at: "dst", contents: "existing contents")
        let srcTargetSnapshot = try Support.ItemSnapshot.capture(at: srcTarget)

        try fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .overwrite, symlinkOption: .copyTarget)
        )

        try Support.expectItem(at: dst, matches: srcTargetSnapshot, using: .copiedItem)

    }

}

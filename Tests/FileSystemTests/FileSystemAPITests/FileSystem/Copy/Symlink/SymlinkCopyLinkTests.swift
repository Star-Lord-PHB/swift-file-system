import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Symlink as link")
    struct SymlinkCopyLinkTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.SymlinkCopyLinkTests {

    enum TargetKind: String, CaseIterable {
        case file
        case symlink
        case danglingSymlink
        case directory
    }


    /// The flavor of the copied source link. On Windows file and directory symlinks are distinct
    /// objects with separate copy paths, so the shared cases run with both flavors.
    enum SrcLinkKind: String, CaseIterable {
        case fileLink
        case directoryLink
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


    /// Creates the source link at `src-link` together with its target.
    private func makeSrcLink(_ kind: SrcLinkKind) throws -> FilePath {
        switch kind {
            case .fileLink:
                let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
                return try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
            case .directoryLink:
                let srcTarget = try workspace.makeFixture(
                    at: "target-dir",
                    [
                        "file.txt": .file(contents: "contents")
                    ]
                )
                return try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        }
    }


    @Test
    func `Copies a file link as a link`() throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = workspace.path("dst-link")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)
        let srcTargetSnapshot = try Support.ItemSnapshot.capture(at: srcTarget)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        try Support.expectItem(at: srcTarget, matches: srcTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Copies a relative link verbatim`() throws {

        try workspace.makeFile(at: "a/target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "a/link", pointingTo: "target.txt")
        try workspace.makeDirectory(at: "b")
        let dst = workspace.path("b/link")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)
        try #require(linkSnapshot.payload == .symlinkTarget("target.txt"))

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies a directory link as a link`() throws {

        let src = try makeSrcLink(.directoryLink)
        let dst = workspace.path("dst-link")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies a dangling link`() throws {

        let missing = workspace.path("missing")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: missing)
        let dst = workspace.path("dst-link")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        try Support.expectItemNotExistNoFollow(at: missing)

    }


    @Test(
        arguments: [.overwrite, .skip, .error] as [FileOperationOptions.CopyTargetExistOption],
                   SrcLinkKind.allCases
    )
    func `Copies to a missing destination regardless of existing-target option`(
        option: FileOperationOptions.CopyTargetExistOption,
        srcKind: SrcLinkKind
    ) throws {

        let src = try makeSrcLink(srcKind)
        let dst = workspace.path("dst-link")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: option))

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)

    }


    @Test
    func `Overwrite replaces an existing file with the link`() throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = try workspace.makeFile(at: "container/dst", contents: "existing contents")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        // The temporary link used for the replacement must not survive.
        let containerEntries = try FileManager.default.contentsOfDirectory(
            atPath: workspace.path("container").string
        )
        #expect(containerEntries == ["dst"])

    }


    @Test
    func `Overwrite replaces an existing file with a directory link`() throws {

        let src = try makeSrcLink(.directoryLink)
        let dst = try workspace.makeFile(at: "container/dst", contents: "existing contents")
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        // The temporary link used for the replacement must not survive.
        let containerEntries = try FileManager.default.contentsOfDirectory(
            atPath: workspace.path("container").string
        )
        #expect(containerEntries == ["dst"])

    }


    @Test
    func `Overwrite replaces an existing link and preserves target`() throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dstTarget = try workspace.makeFile(at: "old-target.txt", contents: "old target contents")
        let dst = try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dstTargetSnapshot = try Support.ItemSnapshot.capture(at: dstTarget)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        try Support.expectItem(at: dstTarget, matches: dstTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Overwrite replaces an existing link with a directory link`() throws {

        let src = try makeSrcLink(.directoryLink)
        let dstTarget = try workspace.makeFile(at: "old-target.txt", contents: "old target contents")
        let dst = try workspace.makeSymlink(at: "container/dst", pointingTo: dstTarget)
        let linkSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dstTargetSnapshot = try Support.ItemSnapshot.capture(at: dstTarget)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        try Support.expectItem(at: dst, matches: linkSnapshot, using: .copiedItem)
        try Support.expectItem(at: dstTarget, matches: dstTargetSnapshot, using: .unchanged)

    }


    @Test(arguments: SrcLinkKind.allCases)
    func `Overwrite onto a directory fails`(srcKind: SrcLinkKind) throws {

        let src = try makeSrcLink(srcKind)
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


    @Test(arguments: TargetKind.allCases, SrcLinkKind.allCases)
    func `Skip leaves an existing target unchanged`(kind: TargetKind, srcKind: SrcLinkKind) throws {

        let src = try makeSrcLink(srcKind)
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


    @Test(arguments: TargetKind.allCases, SrcLinkKind.allCases)
    func `Existing-target error fails and changes nothing`(
        kind: TargetKind,
        srcKind: SrcLinkKind
    ) throws {

        let src = try makeSrcLink(srcKind)
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

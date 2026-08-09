import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Directory merge")
    struct DirectoryMergeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.DirectoryMergeTests {

    enum TargetKind: String, CaseIterable {
        case file
        case symlink
        case danglingSymlink
    }


    /// Policy for an existing directory whose metadata the merge overwrites in place.
    ///
    /// On Darwin and FreeBSD the copy writes the creation time by lowering the destination's
    /// birth time, which cannot raise an older value; the direction semantics get their own
    /// tests in Metadata/BSD.
    private var overwrittenExistingDirPolicy: Support.ItemComparisonPolicy {
        #if canImport(Darwin) || os(FreeBSD)
        .copiedItem.excluding(.creationTime)
        #else
        .copiedItem
        #endif
    }


    /// Policy for a retained destination directory that gained children during the merge.
    ///
    /// Creating entries updates the directory's modification and status-change times (and its
    /// access time on some platforms) even though nothing is copied onto the directory itself.
    private var retainedGainingDirPolicy: Support.ItemComparisonPolicy {
        .unchanged.excluding([.accessTime, .modificationTime, .statusChangeTime])
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
        }
    }


    /// Expects `container` to be unchanged, except for its own access time: probing the existing
    /// destination starts with a directory-creation attempt, and on Windows that failed attempt
    /// pushes the parent directory's access time.
    private func expectContainerUnchanged(
        matching snapshot: Support.TreeSnapshot,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var expectation = Support.TreeExpectation(matching: snapshot, using: .unchanged)
        try expectation.updatePolicies(
            ["": .unchanged.excluding(.accessTime)],
            sourceLocation: sourceLocation
        )
        try Support.expectTree(
            at: workspace.path("container"),
            matches: expectation,
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Overwrite merges into an existing directory`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file"),
                "link": .symlink(target: "file.txt"),
                "a": [
                    "nested.txt": .file(contents: "src nested"),
                    "new.txt": .file(contents: "src new"),
                ],
                "c": [
                    "inner.txt": .file(contents: "src inner")
                ],
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "file.txt": .file(contents: "dst file"),
                "link": .symlink(target: "keep.txt"),
                "keep.txt": .file(contents: "dst keep"),
                "a": [
                    "nested.txt": .file(contents: "dst nested"),
                    "keep.txt": .file(contents: "dst a keep"),
                ],
                "b": [
                    "extra.txt": .file(contents: "dst extra")
                ],
            ]
        )
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        try expectation.updatePolicies([
            "": overwrittenExistingDirPolicy,
            "a": overwrittenExistingDirPolicy,
        ])
        try expectation.add(
            from: dstSnapshot,
            items: [
                "keep.txt": .unchanged,
                "a/keep.txt": .unchanged,
                "b": .unchanged,
                "b/extra.txt": .unchanged,
            ]
        )
        try Support.expectTree(at: dst, matches: expectation)

    }


    @Test
    func `Skip preserves existing items and copies new ones`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file"),
                "link": .symlink(target: "file.txt"),
                "a": [
                    "nested.txt": .file(contents: "src nested"),
                    "new.txt": .file(contents: "src new"),
                ],
                "c": [
                    "inner.txt": .file(contents: "src inner")
                ],
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "file.txt": .file(contents: "dst file"),
                "link": .symlink(target: "keep.txt"),
                "keep.txt": .file(contents: "dst keep"),
                "a": [
                    "nested.txt": .file(contents: "dst nested"),
                    "keep.txt": .file(contents: "dst a keep"),
                ],
                "b": [
                    "extra.txt": .file(contents: "dst extra")
                ],
            ]
        )
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .skip))

        var expectation = Support.TreeExpectation(matching: dstSnapshot, using: .unchanged)
        try expectation.updatePolicies([
            "": retainedGainingDirPolicy,
            "a": retainedGainingDirPolicy,
        ])
        try expectation.add(
            from: srcSnapshot,
            items: [
                "a/new.txt": .copiedItem,
                "c": .copiedItem,
                "c/inner.txt": .copiedItem,
            ]
        )
        try Support.expectTree(at: dst, matches: expectation)

    }


    @Test
    func `Skip skips a subtree whose destination is a file`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "child.txt": .file(contents: "src child")
                ],
                "sibling.txt": .file(contents: "src sibling"),
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": .file(contents: "dst file")
            ]
        )
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .skip))

        var expectation = Support.TreeExpectation(matching: dstSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": retainedGainingDirPolicy])
        try expectation.add(from: srcSnapshot, items: ["sibling.txt": .copiedItem])
        try Support.expectTree(at: dst, matches: expectation)

    }


    @Test
    func `Merge fails when a directory replaces a file`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "child.txt": .file(contents: "src child")
                ]
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": .file(contents: "dst file")
            ]
        )
        let mismatchSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("sub"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .overwrite),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .notADirectory)
        try Support.expectItem(at: dst.appending("sub"), matches: mismatchSnapshot, using: .unchanged)

    }


    @Test
    func `Merge fails when a file replaces a directory`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": .file(contents: "src file")
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": [
                    "child.txt": .file(contents: "dst child")
                ]
            ]
        )
        let mismatchSnapshot = try Support.TreeSnapshot.capture(at: dst.appending("sub"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .overwrite),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .isADirectory)
        try Support.expectTree(at: dst.appending("sub"), matches: mismatchSnapshot, using: .unchanged)

    }


    @Test(arguments: TargetKind.allCases)
    func `Overwrite onto a non-directory fails`(kind: TargetKind) throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try makeExistingTarget(kind)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .overwrite),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .notADirectory)
        try expectContainerUnchanged(matching: containerSnapshot)

    }


    @Test(arguments: TargetKind.allCases)
    func `Skip leaves a non-directory target unchanged`(kind: TargetKind) throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try makeExistingTarget(kind)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .skip))

        try expectContainerUnchanged(matching: containerSnapshot)

    }


    @Test(arguments: TargetKind.allCases)
    func `Existing-target error fails and changes nothing`(kind: TargetKind) throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try makeExistingTarget(kind)
        let containerSnapshot = try Support.TreeSnapshot.capture(at: workspace.path("container"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .error),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .alreadyExists)
        try expectContainerUnchanged(matching: containerSnapshot)

    }

}



#if !canImport(WinSDK)
extension FileSystemAPITests.CopyTests.DirectoryMergeTests {

    private func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }


    @Test
    func `Overwrite writes into a restricted existing directory`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "sub": [
                    "nested.txt": .file(contents: "nested contents")
                ],
            ]
        )
        let dst = try workspace.makeDirectory(at: "dst")
        try setPermissions(0o500, at: dst)
        // A failed copy would leave the directory unwritable and break workspace cleanup.
        defer { try? setPermissions(0o755, at: dst) }
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        // NOTE: When running as root (Linux test container) the restriction itself is not
        // enforced, but the final-metadata assertions below still apply.
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        try expectation.updatePolicies(["": overwrittenExistingDirPolicy])
        try Support.expectTree(at: dst, matches: expectation)

    }

}
#endif

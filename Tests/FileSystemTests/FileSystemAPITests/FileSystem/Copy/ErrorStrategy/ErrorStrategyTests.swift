import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#endif



extension FileSystemAPITests.CopyTests {

    @Suite("Error strategy")
    struct ErrorStrategyTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.ErrorStrategyTests {

    /// The per-item failures produced by merging the mismatch fixtures.
    private var mismatchErrors: [(FilePath, RecursiveCopySingleItemError.Operation, PlatformErrorKind)] {
        [("clash-dir", .copyContents, .notADirectory), ("clash-file", .copyContents, .isADirectory)]
    }


    /// Source tree for the shared mismatch scenario. "clash-dir" carries children so the
    /// report proves that a failed directory yields one single error for its whole subtree.
    private func makeMismatchSrc() throws -> FilePath {
        try workspace.makeFixture(
            at: "src",
            [
                "ok.txt": .file(contents: "src ok"),
                "sub": [
                    "inner.txt": .file(contents: "src inner")
                ],
                "clash-dir": [
                    "child-a.txt": .file(contents: "src child a"),
                    "child-b.txt": .file(contents: "src child b"),
                ],
                "clash-file": .file(contents: "src clash"),
            ]
        )
    }


    /// Destination tree whose merge with the mismatch source fails at "clash-dir"
    /// (directory over file) and "clash-file" (file over directory).
    private func makeMismatchDst(at relativePath: String) throws -> FilePath {
        try workspace.makeFixture(
            at: relativePath,
            [
                "keep.txt": .file(contents: "dst keep"),
                "clash-dir": .file(contents: "dst clash-dir"),
                "clash-file": [
                    "child.txt": .file(contents: "dst child")
                ],
            ]
        )
    }


    /// The tree expected after a non-aborting merge of the mismatch fixtures: everything
    /// copied except the two mismatched items, which keep their destination state.
    private func partialMergeExpectation(
        srcSnapshot: Support.TreeSnapshot,
        dstSnapshot: Support.TreeSnapshot
    ) throws -> Support.TreeExpectation {
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        try expectation.updatePolicies(["": CopyTests.overwrittenExistingDirPolicy])
        expectation.removeItem(at: "clash-dir/child-a.txt")
        expectation.removeItem(at: "clash-dir/child-b.txt")
        try expectation.add(
            from: dstSnapshot,
            items: [
                "keep.txt": .unchanged,
                "clash-dir": .unchanged,
                "clash-file": .unchanged,
                "clash-file/child.txt": .unchanged,
            ]
        )
        return expectation
    }


    @Test
    func `Abort on error stops at the first failure`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "clash": [
                        "child.txt": .file(contents: "src child")
                    ]
                ]
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": [
                    "clash": .file(contents: "dst clash")
                ]
            ]
        )
        let clashSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("sub/clash"))

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(existingTarget: .overwrite),
                errorStrategy: .abortOnError
            )
        }

        #expect(error?.kind == .notADirectory)
        // The one place the operation is asserted: its paths must be the copy roots joined
        // with the failing item's relative path.
        #expect(
            error?.operation == .copy(
                srcPath: src.appending("sub/clash"),
                dstPath: dst.appending("sub/clash")
            )
        )
        try Support.expectItem(at: dst.appending("sub/clash"), matches: clashSnapshot, using: .unchanged)

    }


    @Test
    func `Collect and return reports every failure and copies the rest`() throws {

        let src = try makeMismatchSrc()
        let dst = try makeMismatchDst(at: "dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        let report = fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .overwrite),
            errorStrategy: .collectAndReturn
        )

        try CopyTests.expectReport(report, srcRoot: src, dstRoot: dst, errors: mismatchErrors)
        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, dstSnapshot: dstSnapshot)
        )

    }


    @Test
    func `Collect and throw is the default and reports every failure`() throws {

        let src = try makeMismatchSrc()
        let dst = try makeMismatchDst(at: "dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        let report = try CopyTests.requireThrownReport {
            try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))
        }

        // Pinned to the same expectations as `.collectAndReturn`: the two strategies share
        // the collection and only differ in how the report is delivered.
        try CopyTests.expectReport(report, srcRoot: src, dstRoot: dst, errors: mismatchErrors)
        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, dstSnapshot: dstSnapshot)
        )

    }


    @Test
    func `Ignore all copies the rest silently`() throws {

        let src = try makeMismatchSrc()
        let dst = try makeMismatchDst(at: "dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .overwrite),
            errorStrategy: .ignoreAll
        )

        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, dstSnapshot: dstSnapshot)
        )

    }


    @Test
    func `A directory keeps its source times despite failed children`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "clash": [
                        "child.txt": .file(contents: "src child")
                    ],
                    "good.txt": .file(contents: "src good"),
                ]
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": [
                    "clash": .file(contents: "dst clash")
                ]
            ]
        )
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        let report = fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .overwrite),
            errorStrategy: .collectAndReturn
        )

        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [("sub/clash", .copyContents, .notADirectory)]
        )
        // The directory's committed metadata claims completeness even though a child failed
        try Support.expectItem(
            at: dst.appending("sub"),
            matches: try #require(srcSnapshot["sub"]),
            using: CopyTests.overwrittenExistingDirPolicy
        )
        try Support.expectItem(
            at: dst.appending("sub/good.txt"),
            matches: try #require(srcSnapshot["sub/good.txt"]),
            using: .copiedItem
        )
        try Support.expectItem(
            at: dst.appending("sub/clash"),
            matches: try #require(dstSnapshot["sub/clash"]),
            using: .unchanged
        )

    }

}



#if !canImport(WinSDK)
extension FileSystemAPITests.CopyTests.ErrorStrategyTests {

    @Test
    func `Fifo entries are reported as unsupported and skipped`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "ok.txt": .file(contents: "src ok")
            ]
        )
        try #require(mkfifo(src.appending("fifo").string, 0o644) == 0)
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        let report = fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [("fifo", .copyContents, .unsupported)]
        )
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        expectation.removeItem(at: "fifo")
        try Support.expectTree(at: dst, matches: expectation)

    }

}
#endif



#if canImport(WinSDK)
extension FileSystemAPITests.CopyTests.ErrorStrategyTests {

    @Test
    func `Junction entries are reported as unsupported and skipped`() throws {

        let junctionTarget = try workspace.makeFixture(
            at: "junction-target",
            [
                "loot.txt": .file(contents: "target contents")
            ]
        )
        let src = try workspace.makeFixture(
            at: "src",
            [
                "ok.txt": .file(contents: "src ok")
            ]
        )
        try Support.makeWindowsJunction(at: src.appending("junction"), pointingTo: junctionTarget)
        let dst = workspace.path("dst")
        // The tree capture follows the junction like a directory; drop it and its
        // followed contents from the expectation below.
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        let report = try fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        try CopyTests.expectReport(
            report,
            srcRoot: src,
            dstRoot: dst,
            errors: [("junction", .copyContents, .unsupported)]
        )
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        expectation.removeItem(at: "junction")
        expectation.removeItem(at: "junction/loot.txt")
        try Support.expectTree(at: dst, matches: expectation)

    }

}
#endif

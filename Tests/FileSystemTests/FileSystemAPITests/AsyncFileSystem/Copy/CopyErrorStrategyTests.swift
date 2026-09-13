import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests.CopyTests {

    /// Each built-in strategy's outcome arrives through the async driver in the shape the
    /// synchronous group pins for it. One test per strategy, because together they cover
    /// every combination of the strategy's associated types the driver's generic plumbing
    /// must carry: a thrown `PlatformError`, a `Never`-throwing value return, and `Void`.
    @Suite("Error strategy")
    struct CopyErrorStrategyTests {

        typealias Support = AsyncFileSystemAPITests.Support
        typealias CopyTests = AsyncFileSystemAPITests.CopyTests

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.CopyTests.CopyErrorStrategyTests {

    /// The mismatch every test here runs into while merging into the existing destination
    /// under the default `.overwrite`: "clash" is a directory in the source and a file in the
    /// destination.
    private var clashError: (FilePath, RecursiveCopyResult.ItemOperation, PlatformErrorKind) {
        ("clash", .copyContents, .notADirectory)
    }


    private func makeClashSrc() throws -> FilePath {
        try workspace.makeFixture(
            at: "src",
            [
                "clash": [
                    "child.txt": .file(contents: "src child")
                ],
                "ok.txt": .file(contents: "src ok"),
            ]
        )
    }


    private func makeClashDst() throws -> FilePath {
        try workspace.makeFixture(
            at: "dst",
            [
                "clash": .file(contents: "dst clash")
            ]
        )
    }


    /// The tree expected after a non-aborting merge of the clash fixtures: everything copied
    /// except the mismatched item, which keeps its destination state.
    private func partialMergeExpectation(
        srcSnapshot: Support.TreeSnapshot,
        clashSnapshot: Support.ItemSnapshot
    ) throws -> Support.TreeExpectation {
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .copiedItem)
        // The destination root exists and has its metadata overwritten in place.
        try expectation.updatePolicies(["": CopyTests.overwrittenExistingDirPolicy])
        expectation.removeItem(at: "clash/child.txt")
        expectation.expectItem(at: "clash", matching: clashSnapshot, using: .unchanged)
        return expectation
    }


    @Test
    func `Collect and throw is the default and throws the collected report`() async throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let clashSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("clash"))
        let asyncFileSystem = self.asyncFileSystem

        let report = try await CopyTests.requireThrownReport {
            try await asyncFileSystem.copyItem(at: src, to: dst)
        }

        try CopyTests.expectReport(report, srcRoot: src, dstRoot: dst, errors: [clashError])
        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, clashSnapshot: clashSnapshot)
        )

    }


    @Test
    func `Collect and return returns the result with the collected errors`() async throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let clashSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("clash"))

        let result = await asyncFileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)

        #expect(result.operationCancelled == false)
        try CopyTests.expectReport(
            result.makeItemErrorReport(), srcRoot: src, dstRoot: dst, errors: [clashError]
        )
        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, clashSnapshot: clashSnapshot)
        )

    }


    @Test
    func `Abort on error throws the item error`() async throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let clashSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("clash"))

        let error = await #expect(throws: PlatformError.self) {
            try await asyncFileSystem.copyItem(at: src, to: dst, errorStrategy: .abortOnError)
        }

        #expect(error?.kind == .notADirectory)
        // Whether the other entries were copied before the abort depends on enumeration
        // order, so only the mismatched item is checked.
        try Support.expectItem(at: dst.appending("clash"), matches: clashSnapshot, using: .unchanged)

    }


    @Test
    func `Ignore all returns normally and copies the rest`() async throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let clashSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("clash"))

        try await asyncFileSystem.copyItem(at: src, to: dst, errorStrategy: .ignoreAll)

        try Support.expectTree(
            at: dst,
            matches: partialMergeExpectation(srcSnapshot: srcSnapshot, clashSnapshot: clashSnapshot)
        )

    }

}

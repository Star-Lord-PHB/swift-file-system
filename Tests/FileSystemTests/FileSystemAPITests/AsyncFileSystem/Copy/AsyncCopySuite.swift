import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    /// Contract tests for `AsyncFileSystem.copyItem`. Unlike the thin shells around it, the
    /// method is a driver of its own: it steps the package-level `CopyItemHandler` on the
    /// executor in time slices, bridges Swift task cancellation onto the handler's token and
    /// hands the finished session to the error strategy. The copy semantics themselves (what
    /// is copied, the metadata, the per-item errors) come from the handler and stay pinned by
    /// the synchronous `FileSystemAPITests.CopyTests`; these tests only cover what the driver
    /// adds:
    ///
    /// - forwarding: the roots, the options and the strategy reach the handler, and a copy
    ///   whose steps are spread over several time slices still produces the exact result;
    /// - the error strategies: every combination of a strategy's associated types crosses the
    ///   driver's generic plumbing unchanged (a typed rethrow, `Never`, a returned result);
    /// - pre-cancellation: a task that is already cancelled gets the strategy's cancelled
    ///   outcome without a handler being run.
    ///
    /// Cancellation arriving while a copy is in progress, and two sliced copies sharing one
    /// worker, depend on timing between tasks; they are exercised by hand rather than here.
    @Suite("Copy")
    struct CopyTests {}

}



// Helpers shared by the copy suites. They mirror the synchronous `FileSystemAPITests.CopyTests`
// helpers instead of calling them, so this group does not reach into the synchronous tests.
extension AsyncFileSystemAPITests.CopyTests {

    /// Policy for an existing directory whose metadata the copy overwrites in place.
    ///
    /// On Darwin and FreeBSD the copy writes the creation time by lowering the destination's
    /// birth time, which cannot raise an older value.
    static var overwrittenExistingDirPolicy: FileSystemTestSupport.ItemComparisonPolicy {
        #if canImport(Darwin) || os(FreeBSD)
        .copiedItem.excluding(.creationTime)
        #else
        .copiedItem
        #endif
    }


    /// Asserts a report's root paths and its complete error list. The comparison is
    /// deliberately unordered (directory enumeration order is platform-dependent), and an
    /// item may legitimately appear once per failed operation.
    static func expectReport(
        _ report: RecursiveCopyResult.ItemErrorReport?,
        srcRoot: FilePath,
        dstRoot: FilePath,
        errors expectedErrors: [(FilePath, RecursiveCopyResult.ItemOperation, PlatformErrorKind)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let report = try #require(report, sourceLocation: sourceLocation)
        #expect(report.srcRootPath == srcRoot, sourceLocation: sourceLocation)
        #expect(report.dstRootPath == dstRoot, sourceLocation: sourceLocation)
        let collected = report.errors
            .map { "\($0.itemRelativePath.string) | \($0.operation) | \($0.kind)" }
            .sorted()
        let expected = expectedErrors
            .map { "\($0.0.string) | \($0.1) | \($0.2)" }
            .sorted()
        #expect(collected == expected, sourceLocation: sourceLocation)
    }


    /// Runs `body`, requiring it to fail with the `collectAndThrow` shape — a `PlatformError`
    /// with kind `.unknown` and a `recursiveCopy` operation wrapping the collected report —
    /// and returns the report.
    static func requireThrownReport(
        by body: () async throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> RecursiveCopyResult.ItemErrorReport {
        let error = await #expect(throws: PlatformError.self, sourceLocation: sourceLocation) {
            try await body()
        }
        let platformError = try #require(error, sourceLocation: sourceLocation)
        #expect(platformError.kind == .unknown, sourceLocation: sourceLocation)
        let report = try #require(
            platformError.underlyingError as? RecursiveCopyResult.ItemErrorReport,
            sourceLocation: sourceLocation
        )
        #expect(
            platformError.operation == .recursiveCopy(
                srcRootPath: report.srcRootPath,
                dstRootPath: report.dstRootPath
            ),
            sourceLocation: sourceLocation
        )
        return report
    }

}

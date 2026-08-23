import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Copy")
    struct CopyTests {}

}



// Helpers shared by more than one copy suite.
extension FileSystemAPITests.CopyTests {

    /// Policy for an existing directory whose metadata the copy overwrites in place.
    ///
    /// On Darwin and FreeBSD the copy writes the creation time by lowering the destination's
    /// birth time, which cannot raise an older value; the direction semantics get their own
    /// tests in Metadata/BSD.
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
        _ report: RecursiveCopyErrorReport?,
        srcRoot: FilePath,
        dstRoot: FilePath,
        errors expectedErrors: [(FilePath, RecursiveCopySingleItemError.Operation, PlatformErrorKind)],
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
        by body: () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> RecursiveCopyErrorReport {
        let error = #expect(throws: PlatformError.self, sourceLocation: sourceLocation) {
            try body()
        }
        let platformError = try #require(error, sourceLocation: sourceLocation)
        #expect(platformError.kind == .unknown, sourceLocation: sourceLocation)
        let report = try #require(
            platformError.underlyingError as? RecursiveCopyErrorReport,
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

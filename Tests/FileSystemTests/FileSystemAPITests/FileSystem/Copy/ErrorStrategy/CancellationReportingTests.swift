import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// How the error strategies report a cancelled copy: cancellation is the outcome of the whole
    /// operation rather than an item error, and item errors collected before it stay attached.
    /// The handler is driven to the cancellation point step by step and then finished with
    /// `perform()`, which is where the strategy shapes the outcome.
    @Suite("Cancellation reporting")
    struct CancellationReportingTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.CancellationReportingTests {

    /// A handler whose token is already cancelled, for the strategy comparison below.
    private func makeCancelledHandler<S: CopyTests.CopyErrorStrategy>(
        src: FilePath,
        dst: FilePath,
        errorStrategy: S
    ) -> CopyItemHandler<S> {
        let token = CancellationToken()
        token.cancel()
        return .init(
            srcRootPath: src, dstRootPath: dst, cancellationToken: token, errorStrategy: errorStrategy
        )
    }


    /// The mismatch recorded before the cancellation in the tests below: "clash" is a directory
    /// in the source and a file in the destination.
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


    @Test
    func `Cancellation before the first step is reported by every strategy`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src contents")
            ]
        )
        let dst = workspace.path("dst")

        var returning = makeCancelledHandler(src: src, dst: dst, errorStrategy: .collectAndReturn)
        let result = returning.perform()
        #expect(result.operationCancelled == true)
        #expect(result.itemErrors == nil)
        #expect(result.srcRootPath == src)
        #expect(result.dstRootPath == dst)

        // The throwing strategies all throw the same shape: kind `.cancelled` without a system
        // code, and the cancellation itself as the cause.
        var aborting = makeCancelledHandler(src: src, dst: dst, errorStrategy: .abortOnError)
        let abortError = #expect(throws: PlatformError.self) { try aborting.perform() }
        #expect(abortError?.kind == .cancelled)
        #expect(abortError?.systemCode == nil)
        #expect(abortError?.underlyingError is CancellationError)

        var throwing = makeCancelledHandler(src: src, dst: dst, errorStrategy: .collectAndThrow)
        let throwError = #expect(throws: PlatformError.self) { try throwing.perform() }
        #expect(throwError?.kind == .cancelled)
        #expect(throwError?.systemCode == nil)
        #expect(throwError?.underlyingError is CancellationError)

        var ignoring = makeCancelledHandler(src: src, dst: dst, errorStrategy: .ignoreAll)
        let ignoreError = #expect(throws: PlatformError.self) { try ignoring.perform() }
        #expect(ignoreError?.kind == .cancelled)
        #expect(ignoreError?.systemCode == nil)
        #expect(ignoreError?.underlyingError is CancellationError)

        try Support.expectItemNotExistNoFollow(at: dst)

    }


    @Test
    func `Collect and throw attaches the collected item errors as the cause`() throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite),
            cancellationToken: token,
            errorStrategy: .collectAndThrow
        )

        // Step until the mismatch has been recorded, then cancel before the copy can finish.
        try CopyTests.step(&handler) { $0.errorCollector.errors.value != nil }
        token.cancel()
        let error = #expect(throws: PlatformError.self) { try handler.perform() }
        // Cancellation stays the primary signal; the report travels along as the cause.
        #expect(error?.kind == .cancelled)
        #expect(error?.systemCode == nil)
        let report = try #require(error?.underlyingError as? RecursiveCopyResult.ItemErrorReport)
        try CopyTests.expectReport(report, srcRoot: src, dstRoot: dst, errors: [clashError])

    }


    @Test
    func `Collect and return keeps the collected item errors beside the cancellation`() throws {

        let src = try makeClashSrc()
        let dst = try makeClashDst()
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite),
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        try CopyTests.step(&handler) { $0.errorCollector.errors.value != nil }
        token.cancel()
        let result = handler.perform()
        #expect(result.operationCancelled == true)
        try CopyTests.expectReport(
            result.makeItemErrorReport(), srcRoot: src, dstRoot: dst, errors: [clashError]
        )

    }

}

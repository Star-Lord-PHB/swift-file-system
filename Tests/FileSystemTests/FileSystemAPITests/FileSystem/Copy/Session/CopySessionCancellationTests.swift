import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// Cancellation takes effect at the next step: the copy ends with whatever the interrupted
    /// step left cleaned up, and nothing is reported as an item error. Every test sets the token
    /// between two steps, so the outcome does not depend on timing.
    @Suite("Session cancellation")
    struct CopySessionCancellationTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.CopySessionCancellationTests {

    /// Cancels when the volume does not push access times on reads: proving that a pushed
    /// access time was restored needs the push.
    private func requireAccessTimeUpdates(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if try !Support.volumeUpdatesAccessTimeOnRead(in: workspace, sourceLocation: sourceLocation) {
            try Test.cancel(
                "The volume does not update access times on read",
                sourceLocation: sourceLocation
            )
        }
    }


    private func entryCount(of directory: FilePath) throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: directory.string).count
    }


    @Test
    func `Cancelling before the first step ends the copy without creating the target`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src contents")
            ]
        )
        let dst = workspace.path("dst")
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(handler.operationCancelled == true)
        // Cancellation is not an item error and does not go through the error strategy.
        #expect(handler.errorCollector.errors.value == nil)
        try Support.expectItemNotExistNoFollow(at: dst)
        // A step after the end changes nothing.
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))

    }


    @Test
    func `Cancelling with a file in progress keeps the existing target intact`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src contents")
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "file.txt": .file(contents: "dst contents")
            ]
        )
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dstFileSnapshot = try Support.ItemSnapshot.capture(at: dst.appending("file.txt"))
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite),
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        // The root directory, then the file registration: on POSIX the staged copy now exists
        // beside the target, on Windows only the copy task is recorded.
        try CopyTests.step(&handler) {
            CopyTests.sessionState(of: $0) == .copying(hasDirectory: true, hasFile: true)
        }
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(handler.errorCollector.errors.value == nil)
        // The target keeps its own state and the staged file is gone.
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .logicalContents)
        expectation.expectItem(at: "file.txt", matching: dstFileSnapshot, using: .unchanged)
        try Support.expectTree(at: dst, matches: expectation, allowingMissingItems: true)

    }


    @Test
    func `Cancelling with a file in progress restores the source directory access time`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src contents")
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "file.txt": .file(contents: "dst contents")
            ]
        )
        try Support.ageAccessTime(at: src)
        let srcBefore = try Times.capture(at: src)
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite, preserveSrcAccessTime: true),
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        // Enumerating the root pushes its access time before the file is registered.
        try CopyTests.step(&handler) {
            CopyTests.sessionState(of: $0) == .copying(hasDirectory: true, hasFile: true)
        }
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        let srcAfter = try Times.capture(at: src)
        #expect(srcAfter.access == srcBefore.access)
        #expect(srcAfter.modification == srcBefore.modification)

    }


    @Test
    func `Cancelling between entries keeps the completed entries`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "a.txt": .file(contents: "a contents"),
                "b.txt": .file(contents: "b contents"),
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        // Step until the first file, whichever the enumeration yields first, is complete.
        try CopyTests.step(&handler) { handler in
            try CopyTests.sessionState(of: handler) == .copying(hasDirectory: true, hasFile: false)
                && entryCount(of: dst) == 1
        }
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(handler.errorCollector.errors.value == nil)
        #expect(try entryCount(of: dst) == 1)
        try Support.expectTree(
            at: dst, matches: srcSnapshot, using: .logicalContents, allowingMissingItems: true
        )

    }


    @Test
    func `Cancelling with a directory on the stack keeps the directory`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "inner.txt": .file(contents: "inner contents")
                ]
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        try CopyTests.step(&handler) { _ in
            try Support.itemExistsNoFollow(at: dst.appending("sub"))
        }
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(handler.errorCollector.errors.value == nil)
        // Directories are not rolled back; the one still on the stack stays, without contents
        // the source lacks.
        try Support.expectItemExistNoFollow(at: dst.appending("sub"))
        try Support.expectTree(
            at: dst, matches: srcSnapshot, using: .logicalContents, allowingMissingItems: true
        )

    }


    @Test
    func `Cancelling with a directory on the stack restores its source access time`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "inner.txt": .file(contents: "inner contents")
                ]
            ]
        )
        let dst = workspace.path("dst")
        let srcSub = src.appending("sub")
        try Support.ageAccessTime(at: src)
        try Support.ageAccessTime(at: srcSub)
        let srcBefore = try Times.capture(at: src)
        let srcSubBefore = try Times.capture(at: srcSub)
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(preserveSrcAccessTime: true),
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        // Registering the nested file means the subdirectory has been entered and enumerated, so
        // its access time has been pushed while it is still on the stack.
        try CopyTests.step(&handler) {
            CopyTests.sessionState(of: $0) == .copying(hasDirectory: true, hasFile: true)
        }
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(try Times.capture(at: src).access == srcBefore.access)
        #expect(try Times.capture(at: srcSub).access == srcSubBefore.access)
        try Support.expectItemExistNoFollow(at: dst.appending("sub"))

    }

}



#if !canImport(WinSDK)
extension FileSystemAPITests.CopyTests.CopySessionCancellationTests {

    @Test
    func `Cancelling with a directly created target removes the partial file`() throws {

        let chunk = CopyTests.contentCopyChunkSize
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 2 * chunk + 1)
        let container = try workspace.makeDirectory(at: "container")
        let dst = container.appending("dst.bin")
        let token = CancellationToken()
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: token,
            errorStrategy: .collectAndReturn
        )

        // Registration creates the target directly; the first content step fills one block.
        #expect(handler.copyStep() == .paused)
        #expect(handler.copyStep() == .paused)
        #expect(try Support.ItemMetadata.capture(at: dst).size == UInt64(chunk))
        token.cancel()
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: true))
        #expect(handler.errorCollector.errors.value == nil)
        try Support.expectItemNotExistNoFollow(at: dst)
        #expect(try entryCount(of: container) == 0)

    }

}
#endif

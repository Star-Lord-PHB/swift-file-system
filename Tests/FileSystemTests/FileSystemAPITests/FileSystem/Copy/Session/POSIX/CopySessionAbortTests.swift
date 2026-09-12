#if !canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// An abort raised inside a file step cleans up the same way as one raised in a directory
    /// step: the staged file goes, and the directories still on the stack get their source
    /// access times back.
    @Suite("Session abort")
    struct CopySessionAbortTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.CopySessionAbortTests {

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


    /// Replaces the file at `path` with a non-empty directory, so that renaming the staged copy
    /// onto it fails inside the file step, and returns snapshots of the two new items.
    private func replaceWithDirectory(
        at path: FilePath
    ) throws -> (directory: Support.ItemSnapshot, child: Support.ItemSnapshot) {
        try FileManager.default.removeItem(atPath: path.string)
        let child = try workspace.makeFile(at: path.appending("child.txt"), contents: "dst child")
        return (
            directory: try Support.ItemSnapshot.capture(at: path),
            child: try Support.ItemSnapshot.capture(at: child)
        )
    }


    @Test
    func `An abort from the file step removes the staged file and reports the item`() throws {

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
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite),
            cancellationToken: .init(),
            errorStrategy: .abortOnError
        )

        // The root directory, then the file registration: the staged copy exists beside the target.
        try CopyTests.step(&handler) {
            CopyTests.sessionState(of: $0) == .copying(hasDirectory: true, hasFile: true)
        }
        let replaced = try replaceWithDirectory(at: dst.appending("file.txt"))
        // One content block, then the end-of-file step whose rename fails.
        #expect(try CopyTests.stepToCompletion(&handler) == 2)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        let itemErrors = handler.errorCollector.errors.value
        #expect(itemErrors?.count == 1)
        #expect(itemErrors?.first.itemRelativePath == "file.txt")
        #expect(itemErrors?.first.operation == .copyContents)
        #expect(itemErrors?.first.kind == .isADirectory)
        // The destination holds the replaced target and nothing the source lacks: the staged
        // file is gone.
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .logicalContents)
        expectation.expectItem(at: "file.txt", matching: replaced.directory, using: .logicalContents)
        expectation.expectItem(
            at: "file.txt/child.txt", matching: replaced.child, using: .logicalContents
        )
        try Support.expectTree(at: dst, matches: expectation, allowingMissingItems: true)

    }


    @Test
    func `An abort from the file step restores the source directory access time`() throws {

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
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite, preserveSrcAccessTime: true),
            cancellationToken: .init(),
            errorStrategy: .abortOnError
        )

        // Enumerating the root pushes its access time before the file is registered.
        try CopyTests.step(&handler) {
            CopyTests.sessionState(of: $0) == .copying(hasDirectory: true, hasFile: true)
        }
        _ = try replaceWithDirectory(at: dst.appending("file.txt"))
        try CopyTests.stepToCompletion(&handler)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        let srcAfter = try Times.capture(at: src)
        #expect(srcAfter.access == srcBefore.access)
        #expect(srcAfter.modification == srcBefore.modification)

    }

}

#endif

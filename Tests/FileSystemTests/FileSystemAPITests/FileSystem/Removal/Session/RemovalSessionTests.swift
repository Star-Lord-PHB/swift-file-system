import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// White-box tests of the removal session. One `next()` handles one enumerator element; the
    /// first step also tries the root fast path, and when that fails with a non-empty directory it
    /// goes on to the first element in the same step. The token is observed at the start of every
    /// step, so a cancellation set between two steps has a deterministic outcome.
    @Suite("Session")
    struct RemovalSessionTests {

        typealias Support = FileSystemAPITests.Support
        typealias RemovalTests = FileSystemAPITests.RemovalTests

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalSessionTests {

    /// Steps `handler` until it completes and returns the number of steps taken, the completing
    /// one included; fails the test if `stepLimit` steps pass first.
    private func stepToCompletion(
        _ handler: inout RecursiveRemoveItemHandler,
        stepLimit: Int = 100,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Int {
        var steps = 1
        while handler.next() == .paused {
            steps += 1
            try #require(
                steps <= stepLimit,
                "The session did not complete within \(stepLimit) steps",
                sourceLocation: sourceLocation
            )
        }
        return steps
    }


    @Test
    func `A file root completes in one step`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        var handler = RecursiveRemoveItemHandler(path: path)

        #expect(handler.next() == .completed)

        #expect(handler.firstError == nil)
        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `A tree takes one step per enumerator element plus one`() throws {

        // Two files and one directory: the directory takes an entering and a leaving step, the
        // first step also covers the failed root fast path, and the last step removes the root.
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a": .file(contents: "a"),
                "d": [
                    "b": .file(contents: "b")
                ],
            ]
        )
        var handler = RecursiveRemoveItemHandler(path: root)

        #expect(try stepToCompletion(&handler) == 5)

        #expect(handler.firstError == nil)
        try Support.expectItemNotExistNoFollow(at: root)

    }


    @Test
    func `A missing root completes in one step with not found`() throws {

        let path = workspace.path("missing")
        var handler = RecursiveRemoveItemHandler(path: path)

        #expect(handler.next() == .completed)

        #expect(handler.firstError?.kind == .notFound)
        #expect(handler.firstError?.operation == .remove(path))

    }


    @Test
    func `Cancelling before the first step leaves the root untouched`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "sub": [
                    "nested": .file(contents: "nested contents")
                ],
            ]
        )
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)
        let token = CancellationToken()
        var handler = RecursiveRemoveItemHandler(path: root, cancellationToken: token)
        token.cancel()

        #expect(handler.next() == .completed)

        Support.expectStandardCancellation(handler.firstError)
        #expect(handler.firstError?.operation == .remove(root))
        try Support.expectTree(at: root, matches: rootSnapshot, using: .unchanged)

    }


    @Test
    func `Cancelling between steps keeps the remaining entries`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a": .file(contents: "a"),
                "b": .file(contents: "b"),
                "c": .file(contents: "c"),
            ]
        )
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)
        let token = CancellationToken()
        var handler = RecursiveRemoveItemHandler(path: root, cancellationToken: token)
        #expect(handler.next() == .paused)
        #expect(handler.next() == .paused)
        token.cancel()

        #expect(handler.next() == .completed)

        Support.expectStandardCancellation(handler.firstError)
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": RemovalTests.survivingDirectoryPolicy])
        try Support.expectTree(at: root, matches: expectation, allowingMissingItems: true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.string).count == 1)

    }


    @Test
    func `Cancelling after an unremovable entry reports it as the cancellation cause`() throws {

        try RemovalTests.requireObstructionsEffective(in: workspace)
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "locked": [
                    "inner": .file(contents: "inner contents")
                ]
            ]
        )
        let lockedPath = root.appending("locked")
        try RemovalTests.denyRemovalOfChildren(in: lockedPath)
        defer { RemovalTests.restoreRemovalOfChildren(in: lockedPath) }
        let token = CancellationToken()
        var handler = RecursiveRemoveItemHandler(path: root, cancellationToken: token)
        #expect(handler.next() == .paused)
        #expect(handler.next() == .paused)
        #expect(handler.firstError?.kind == .permissionDenied)
        token.cancel()

        #expect(handler.next() == .completed)

        let error = handler.firstError
        #expect(error?.kind == .cancelled)
        #expect(error?.systemCode == nil)
        #expect(error?.operation == .remove(root))
        let cause = try #require(error?.underlyingError as? PlatformError)
        #expect(cause.kind == .permissionDenied)
        #expect(cause.operation == .remove(lockedPath.appending("inner")))

    }


    @Test
    func `An entry removed by someone else during the session is not an error`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a": .file(contents: "a"),
                "b": .file(contents: "b"),
            ]
        )
        var handler = RecursiveRemoveItemHandler(path: root)
        #expect(handler.next() == .paused)
        for name in try FileManager.default.contentsOfDirectory(atPath: root.string) {
            try FileManager.default.removeItem(atPath: root.appending(name).string)
        }

        _ = try stepToCompletion(&handler)

        #expect(handler.firstError == nil)
        try Support.expectItemNotExistNoFollow(at: root)

    }


    @Test
    func `A directory removed by someone else before the session enters it is not an error`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "d": [
                    "x": .file(contents: "x")
                ]
            ]
        )
        var handler = RecursiveRemoveItemHandler(path: root)
        // The first step delivers the directory entry; the session opens it in the next one.
        #expect(handler.next() == .paused)
        try FileManager.default.removeItem(atPath: root.appending("d").string)

        _ = try stepToCompletion(&handler)

        #expect(handler.firstError == nil)
        try Support.expectItemNotExistNoFollow(at: root)

    }

}

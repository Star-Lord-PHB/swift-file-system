import Testing
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests {

    @Suite("Cancellation")
    struct CancellationTests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The sequence is Sendable and Copyable, so it is created outside the task and captured;
// the iterator only exists inside the cancelled task.
extension AsyncRecursiveSequenceAPITests.CancellationTests {

    @Test
    func `Pre-cancelled next reports cancellation`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        await Support.expectPreCancelled {
            var iterator = sequence.makeAsyncIterator()
            return try await iterator.next()
        }

    }


    @Test
    func `Pre-cancelled forEach reports cancellation`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        await Support.expectPreCancelled {
            try await sequence.forEach { _ in }
        }

    }

}

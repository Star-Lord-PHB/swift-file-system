import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests.RemovalTests {

    /// A task that is already cancelled when `removeItem` is entered gets the standard
    /// cancellation error and no handler runs. Cancellation of a removal in progress depends on
    /// timing and is exercised by hand.
    @Suite("Cancellation")
    struct RemovalCancellationTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.RemovalTests.RemovalCancellationTests {

    @Test
    func `Pre-cancelled removal reports cancellation before touching the root`() async throws {

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
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.removeItem(at: root)
        }

        try Support.expectTree(at: root, matches: rootSnapshot, using: .unchanged)

    }

}

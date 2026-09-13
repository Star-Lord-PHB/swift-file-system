import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests.CopyTests {

    /// A task that is already cancelled when `copyItem` is entered gets the strategy's
    /// cancelled outcome and no handler runs: the driver builds the cancelled result itself,
    /// so both the throwing and the returning shape are pinned. Cancellation of a copy in
    /// progress depends on timing and is exercised by hand.
    @Suite("Cancellation")
    struct CopyCancellationTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.CopyTests.CopyCancellationTests {

    @Test
    func `Pre-cancelled copy reports cancellation before creating the target`() async throws {

        let src = try workspace.makeFile(at: "src", contents: "src contents")
        let dst = workspace.path("dst")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.copyItem(at: src, to: dst)
        }

        try Support.expectItemNotExistNoFollow(at: dst)

    }


    @Test
    func `Pre-cancelled copy returns the cancelled result under collect and return`() async throws {

        let src = try workspace.makeFile(at: "src", contents: "src contents")
        let dst = workspace.path("dst")
        let asyncFileSystem = self.asyncFileSystem

        let result = await Support.runPreCancelled {
            await asyncFileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)
        }

        #expect(result.operationCancelled == true)
        #expect(result.itemErrors == nil)
        #expect(result.srcRootPath == src)
        #expect(result.dstRootPath == dst)
        try Support.expectItemNotExistNoFollow(at: dst)

    }

}

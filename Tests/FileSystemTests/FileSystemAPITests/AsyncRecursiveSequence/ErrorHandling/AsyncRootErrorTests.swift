import Testing
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests {

    @Suite("Error handling")
    struct ErrorHandlingTests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: A root that cannot be traversed is the one deterministic failure of the synchronous
// iterator (it fails on its first `next()`), which is what pins the async error path: the
// failure surfaces once and the iterator then ends. The per-entry error elements keep flowing
// through the batches as values and are covered by the synchronous group. Cancellation has its
// own group, and the batch-count precondition sits with the traversal tests.
extension AsyncRecursiveSequenceAPITests.ErrorHandlingTests {

    @Test
    func `Missing root throws once and ends`() async throws {

        let path = workspace.path("missing")

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeAsyncIterator()

        var firstError: PlatformError?
        do throws(PlatformError) {
            _ = try await iterator.next()
        } catch {
            firstError = error
        }
        #expect(firstError?.kind == .notFound)
        #expect(try await iterator.next() == nil)

    }


    @Test
    func `Regular file root throws once and ends`() async throws {

        let path = try workspace.makeFile(at: "file")

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeAsyncIterator()

        var firstError: PlatformError?
        do throws(PlatformError) {
            _ = try await iterator.next()
        } catch {
            firstError = error
        }
        #expect(firstError?.kind == .notADirectory)
        #expect(try await iterator.next() == nil)

    }


    @Test
    func `forEach propagates the root error`() async throws {

        let path = workspace.path("missing")
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        let error = await #expect(throws: PlatformError.self) {
            try await sequence.forEach { _ in }
        }

        #expect(error?.kind == .notFound)

    }

}
